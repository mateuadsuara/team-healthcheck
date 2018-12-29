module Web
  class App
    def call(environment)
      ['200', {'Content-Type' => 'text/html'}, ['<html></html>']]
    end
  end
end
