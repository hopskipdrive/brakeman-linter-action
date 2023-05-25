FROM ruby:3.0.6-bullseye

RUN gem install brakeman

COPY lib /action/lib

CMD ["ruby", "/action/lib/index.rb"]
