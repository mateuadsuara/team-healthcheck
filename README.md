# team-healthcheck

data visualisation tool for assessing team health

# get started

* install frontend dependencies
* install backend dependencies
* `./run`

### install frontend dependencies

first, install elm and elm-test

`npm -g install elm`
`npm -g install elm-test`

more info: https://guide.elm-lang.org/install.html

then, install uglifyjs

`npm -g install uglify-js`

then, install inline-source-cli

`npm -g install inline-source-cli`

### install backend dependencies

first, install elixir:
more info: https://elixir-lang.org/install.html

then, `cd ./backend; mix deps.get`

### test frontend

`./test_frontend`

### test backend

`./test_backend`

### compile frontend

`./compile_frontend`

### compile backend

`./compile_backend`

### start backend

`./start_backend`

# release

`./build_release` will create a `release.zip`
