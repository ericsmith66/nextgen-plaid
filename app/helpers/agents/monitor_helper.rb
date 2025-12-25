module Agents::MonitorHelper
  def persona_color(persona)
    case persona
    when 'SAP'
      'bg-purple-900 text-purple-100'
    when 'CWA'
      'bg-blue-900 text-blue-100'
    when 'CSO'
      'bg-red-900 text-red-100'
    when 'HUMAN'
      'bg-green-900 text-green-100'
    else
      'bg-gray-700 text-gray-200'
    end
  end
end
