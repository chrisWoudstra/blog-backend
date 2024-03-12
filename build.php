<?php

$lambdas = glob("lambda/*");

foreach ($lambdas as $lambda) {
  $cwd = getcwd();
  chdir($lambda);
  $parts = explode("/", $lambda);
  $function_name = end($parts);

  echo "Building " . $function_name . PHP_EOL;
  system('CGO_ENABLED=0 GOARCH=amd64 GOOS=linux go build -mod=vendor -o bootstrap main.go');
  system('zip -r bootstrap.zip bootstrap');

  chdir($cwd);
}