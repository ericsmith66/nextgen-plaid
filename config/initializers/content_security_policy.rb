# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data, "https://*.plaid.com"
    policy.img_src     :self, :https, :data, "https://*.plaid.com"
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline, "https://*.plaid.com"
    policy.style_src   :self, :https, :unsafe_inline
    policy.frame_src   :self, "https://*.plaid.com"
    policy.connect_src :self, :https, "https://*.plaid.com"
    # Allow the Plaid iframe to be interactive with the parent
    # Safari requires 'self' to be present in frame-ancestors to allow child-parent communication
    policy.frame_ancestors :self, "https://*.plaid.com", "https://api.higroundsolutions.com"
    # Safari-specific: Add child-src for iframes
    policy.child_src :self, "https://*.plaid.com"
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  # config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  # config.content_security_policy_nonce_directives = %w(script-src style-src)

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end
