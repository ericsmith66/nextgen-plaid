namespace :sap do
  desc "Interact with SAP iterative tasks (pause/resume, feedback injection)"
  task :interact, [:task_id] => :environment do |_, args|
    task_id = args[:task_id]
    abort "task_id is required" if task_id.blank?

    user_email = ENV["USER_EMAIL"] || User.first&.email
    user = User.find_by(email: user_email)
    auth = SapAgent::AuthService.new(user)

    unless auth.owner? || auth.admin?
      puts "Access denied - Owner only"
      SapAgent::InteractHelper.log_interact_event("interact.denied", task_id: task_id, user: user_email)
      next
    end

    correlation_id = ENV["CORRELATION_ID"].presence || SecureRandom.uuid
    timeout_seconds = (ENV["INTERACT_TIMEOUT_SECONDS"] || 300).to_i
    poll_interval = (ENV["INTERACT_POLL_INTERVAL"] || 10).to_i
    deadline = Time.now + timeout_seconds

    SapAgent::InteractHelper.log_interact_event("interact.start", task_id: task_id, correlation_id: correlation_id)

    loop do
      break if Time.now >= deadline

      state = SapAgent.poll_task_state(task_id)
      status = state[:status]
      puts "Polling state: #{status} (correlation_id=#{correlation_id})"
      SapAgent::InteractHelper.log_interact_event("interact.poll", task_id: task_id, correlation_id: correlation_id, status: status)

      case status
      when "paused"
        resume_token = state[:resume_token]
        print "Enter feedback (optional): "
        feedback = $stdin.gets&.strip
        result = SapAgent.iterate_prompt(task: task_id, resume_token: resume_token, human_feedback: feedback, correlation_id: correlation_id)
        puts "Resumed: #{result[:status]}"
        SapAgent::InteractHelper.log_interact_event("interact.resume", task_id: task_id, correlation_id: correlation_id, status: result[:status])
        break if result[:status] != "paused"
      when "completed"
        output = state[:output] || state[:final_output] || ""
        if SapAgent::InteractHelper.mac_os?
          begin
            IO.popen("pbcopy", "w") { |io| io.write(output) }
            puts "Output copied to clipboard (correlation_id=#{correlation_id})"
          rescue StandardError
            path = SapAgent::InteractHelper.write_temp_output(task_id, output)
            puts "Clipboard unavailable; saved to #{path}"
          end
        else
          path = SapAgent::InteractHelper.write_temp_output(task_id, output)
          puts "Output saved to #{path} (correlation_id=#{correlation_id})"
        end

        SapAgent::InteractHelper.log_interact_event("interact.complete", task_id: task_id, correlation_id: correlation_id)
        break
      when "error"
        puts "Error: #{state[:message]}"
        SapAgent::InteractHelper.log_interact_event("interact.error", task_id: task_id, correlation_id: correlation_id, error: state[:message])
        break
      end

      sleep poll_interval
    end

    if Time.now >= deadline
      puts "Timeout after #{timeout_seconds}s"
      SapAgent::InteractHelper.log_interact_event("interact.timeout", task_id: task_id, correlation_id: correlation_id, timeout_seconds: timeout_seconds)
    end
  end
end