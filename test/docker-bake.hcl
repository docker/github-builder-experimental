# Special target: https://github.com/docker/metadata-action#bake-definition
target "docker-metadata-action" {
  tags = ["github-builder:local"]
}

group "default" {
  targets = ["hello-cross"]
}

group "grp" {
  targets = ["go", "hello"]
}

target "go" {
  inherits = ["docker-metadata-action"]
  dockerfile = "go.Dockerfile"
}

target "go-cross" {
  inherits = ["go"]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "hello" {
  inherits = ["docker-metadata-action"]
  dockerfile = "hello.Dockerfile"
}

target "hello-cross" {
  inherits = ["hello"]
  platforms = ["linux/amd64", "linux/arm64"]
}
