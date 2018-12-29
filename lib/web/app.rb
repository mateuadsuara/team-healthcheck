module Web
  class App
    def call(environment)
      path = environment["PATH_INFO"]

      case path
      when "/"
        html_response('index.html')
      when "/elm.min.js"
        js_response('elm.min.js')
      else
        not_found_response
      end
    end

    def html_response(file)
      ['200', {'Content-Type' => 'text/html'}, [File.read(file)]]
    end

    def js_response(file)
      ['200', {'Content-Type' => 'application/javascript'}, [File.read(file)]]
    end

    def not_found_response
      ['404', {'Content-Type' => 'text/html'}, ['<html>Not found</html>']]
    end
  end
end
