FROM buildkite/plugin-tester:v4.3.0

# Create non-root user
RUN adduser --disabled-password --gecos "" plugin-tester
USER plugin-tester
