FROM ghcr.io/cirruslabs/flutter:3.19.0 AS test-env

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

CMD ["flutter", "test"]