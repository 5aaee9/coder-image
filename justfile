run-container:
  nix build .#container
  sudo docker load < result
  sudo docker run --rm -it coder-image
