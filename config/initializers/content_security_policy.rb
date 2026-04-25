# Application-wide Content Security Policy.
# Defense-in-depth against XSS: even if a stored field rendered raw HTML, an
# attacker can't run external scripts or steal cookies via injected iframes.
#
# Notes for future tightening:
#   * `style-src :unsafe_inline` is required because the app uses inline
#     `style="width: X%"` on macro / progress / checklist progress bars and
#     Tailwind's `safe-top` utility relies on inline padding.
#   * `script-src :unsafe_inline` is required by Chartkick (it emits an inline
#     <script> next to each chart). Once Chartkick is wrapped in a Stimulus
#     controller or a nonce-aware helper, drop :unsafe_inline and switch to a
#     nonce strategy.
#   * `connect-src :self` keeps Hotwire's Turbo Streams + Action Cable on the
#     same origin (we use Solid Cable, no external WS).

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self, :unsafe_inline
    policy.style_src       :self, :unsafe_inline
    policy.img_src         :self
    policy.font_src        :self
    policy.connect_src     :self
    policy.worker_src      :self  # Explicit: Safari historically fails to fall back from default_src
    policy.manifest_src    :self  # Explicit: Safari/iOS PWA install requires manifest_src
    policy.object_src      :none
    policy.frame_ancestors :none
    policy.base_uri        :self
    policy.form_action     :self
  end
end
