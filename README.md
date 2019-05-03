# team-healthcheck

data visualisation tool for assessing team health

# get started

* install frontend dependencies
* install backend dependencies
* `PORT=1234 ./run`

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

`PORT=1234 ./start_backend`

# release

`./build_release` will build a docker image named `team-healthcheck`.

To run the docker container locally:
`docker run -p <local_port>:1234 -e PORT=1234 team-healthcheck` (replace `<local_port>` with the port you want to map to locally)

To kill the running docker container:
``docker kill `docker ps | grep team-healthcheck | cut -f1 -d \t` ``

# demo

Can be used from here:
* For participants: https://team-healthcheck.herokuapp.com/
* For the facilitator: https://team-healthcheck.herokuapp.com/?admin
