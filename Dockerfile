# Dockerfile simples, voltado para rodar a demonstração localmente em
# development (não é uma imagem de produção). Usa RAILS_MAX_THREADS /
# WEB_CONCURRENCY para configurar Puma, ver config/puma.rb e o README.

ARG RUBY_VERSION=3.4.8
FROM ruby:$RUBY_VERSION-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev postgresql-client curl && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

WORKDIR /rails

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
