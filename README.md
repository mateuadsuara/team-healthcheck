# team-healthcheck

data visualisation tool for assessing team health

# get started

* install elm and its dependencies
* install ruby and its dependencies

### install elm and its dependencies

`npm -g install elm`
`npm -g install elm-test`

more info: https://guide.elm-lang.org/install.html

### install ruby and its dependencies

first, install ruby:
more info: https://www.ruby-lang.org/en/documentation/installation/

then, install bundler:
more info: https://bundler.io/#getting-started

then, `bundle install`

### run frontend tests

`elm-test tests/`

### run backend tests

`rspec spec/`

### compile frontend

`elm make src/Main.elm`

### start backend

`rackup --host 0.0.0.0 --port 9292`
