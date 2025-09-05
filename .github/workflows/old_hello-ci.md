name: Hello CI Workflow

on: [push]

jobs:
  hello:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Print Hello
        run: echo "🎉 Hello Continuous Integration!"
