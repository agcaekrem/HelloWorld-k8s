package com.example.helloworldk8s.controller;


import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloWorldK8sController {

    @GetMapping("/hello")
    public String hello() {
        return "E2E - Hello Huawei";
    }
}
