# Ruby metrics collector container
FROM ruby:3.2-slim

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.6.9 && bundle install

# Copy application files
COPY github_metrics.rb ./
COPY lib/ ./lib/

# Create output directory
RUN mkdir -p /app/output

# Set the default command
ENTRYPOINT ["ruby", "github_metrics.rb"]
CMD ["--help"]
