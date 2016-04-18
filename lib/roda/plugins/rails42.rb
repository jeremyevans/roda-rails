class Roda
  module RodaPlugins
    module Rails42
      Flash = ActionDispatch::Flash
      AUTHENTICITY_TOKEN_LENGTH = 32
      DEFAULT_CHECK_CSRF = lambda{|_| !r.is_get?}
      DEFAULT_INVALID_CSRF = lambda do |r|
        r.response.status = 400
        r.halt
      end
      DEFAULT_CSRF_TOKEN = lambda{|r| r['authenticity_token']}

      def self.configure(app, opts={})
        opts = opts.dup
        opts[:check_csrf] ||= DEFAULT_CHECK_CSRF
        opts[:invalid_csrf] ||= DEFAULT_INVALID_CSRF
        opts[:csrf_token] ||= DEFAULT_CSRF_TOKEN
        app.opts[:rails] = opts
      end

      ### Rails 4.2 integration code, most code from Rails
      module InstanceMethods
        def call
          catch(:halt) do
            rails = self.class.opts[:rails]
            r = request
            if instance_exec(r, &rails[:check_csrf])
              unless valid_authenticity_token?(session, instance_exec(r, &rails[:csrf_token]))
                instance_exec(r, &rails[:invalid_csrf])
              end
            end

            super
          end
        end

        def flash
          env[Flash::KEY] ||= Flash::FlashHash.from_session_value(session["flash"])
        end

        def csrf_tag
          "<input type='hidden' name='authenticity_token' value=\"#{masked_authenticity_token(session)}\" />".html_safe
        end

        private

        # Creates a masked version of the authenticity token that varies
        # on each request. The masking is used to mitigate SSL attacks
        # like BREACH.
        def masked_authenticity_token(session)
          one_time_pad = SecureRandom.random_bytes(AUTHENTICITY_TOKEN_LENGTH)
          encrypted_csrf_token = xor_byte_strings(one_time_pad, real_csrf_token(session))
          masked_token = one_time_pad + encrypted_csrf_token
          Base64.strict_encode64(masked_token)
        end

        # Checks the client's masked token to see if it matches the
        # session token. Essentially the inverse of
        # +masked_authenticity_token+.
        def valid_authenticity_token?(session, encoded_masked_token)
          if encoded_masked_token.nil? || encoded_masked_token.empty? || !encoded_masked_token.is_a?(String)
            return false
          end

          begin
            masked_token = Base64.strict_decode64(encoded_masked_token)
          rescue ArgumentError # encoded_masked_token is invalid Base64
            return false
          end

          # See if it's actually a masked token or not. In order to
          # deploy this code, we should be able to handle any unmasked
          # tokens that we've issued without error.

          if masked_token.length == AUTHENTICITY_TOKEN_LENGTH
            # This is actually an unmasked token. This is expected if
            # you have just upgraded to masked tokens, but should stop
            # happening shortly after installing this gem
            compare_with_real_token masked_token, session

          elsif masked_token.length == AUTHENTICITY_TOKEN_LENGTH * 2
            # Split the token into the one-time pad and the encrypted
            # value and decrypt it
            one_time_pad = masked_token[0...AUTHENTICITY_TOKEN_LENGTH]
            encrypted_csrf_token = masked_token[AUTHENTICITY_TOKEN_LENGTH..-1]
            csrf_token = xor_byte_strings(one_time_pad, encrypted_csrf_token)

            compare_with_real_token csrf_token, session

          else
            false # Token is malformed
          end
        end

        def compare_with_real_token(token, session)
          ActiveSupport::SecurityUtils.secure_compare(token, real_csrf_token(session))
        end

        def real_csrf_token(session)
          session[:_csrf_token] ||= SecureRandom.base64(AUTHENTICITY_TOKEN_LENGTH)
          Base64.strict_decode64(session[:_csrf_token])
        end

        def xor_byte_strings(s1, s2)
          s1.bytes.zip(s2.bytes).map { |(c1,c2)| c1 ^ c2 }.pack('c*')
        end
      end
    end

    register_plugin(:rails42, Rails42)
  end
end

