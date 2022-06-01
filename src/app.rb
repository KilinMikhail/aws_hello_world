require 'json'

def handler(event:, context:)
  {
    statusCode: 200,
    body: 'Hello World!'
  }
end
