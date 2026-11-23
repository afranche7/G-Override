# Test runner for machines without Lua + busted (e.g. the Windows dev PC): docker build -f mac/tests/Dockerfile -t g-override-busted .
FROM debian:stable-slim
RUN apt-get update -qq && apt-get install -y -qq lua5.4 lua-busted && rm -rf /var/lib/apt/lists/*
WORKDIR /repo
CMD ["busted"]
