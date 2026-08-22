module Liberic
  module Helpers
    module Invocation
      class Error < StandardError
      end

      extend self

      def raise_on_error(value)
        return value if value == SDK::Fehlercodes::ERIC_OK
        raise Error.new(SDK::Fehlercodes::CODES[value])
      end

      def with_result_buffer(raise_on_error = true, &block)
        handle = SDK::API.mt_rueckgabepuffer_erzeugen(Liberic.instance)
        if raise_on_error
          raise_on_error(yield(handle))
        else
          yield(handle)
        end
        result = SDK::API.mt_rueckgabepuffer_inhalt(Liberic.instance, handle)
        SDK::API.mt_rueckgabepuffer_freigeben(Liberic.instance, handle)
        result
      end

      def with_local_and_server_result_buffers(&block)
        local_handle = SDK::API.mt_rueckgabepuffer_erzeugen(Liberic.instance)
        server_handle = SDK::API.mt_rueckgabepuffer_erzeugen(Liberic.instance)

        error_code = yield(local_handle, server_handle)

        local_result = SDK::API.mt_rueckgabepuffer_inhalt(Liberic.instance, local_handle)
        server_result = SDK::API.mt_rueckgabepuffer_inhalt(Liberic.instance, server_handle)

        return {
          error_code: error_code,
          error_message: SDK::Fehlercodes::CODES[error_code],
          local_result: local_result,
          server_result: server_result
        }
      end
    end
  end
end
