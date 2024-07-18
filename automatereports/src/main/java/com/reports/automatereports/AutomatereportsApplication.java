package com.reports.automatereports;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class AutomatereportsApplication {

	public static void main(String[] args) {
		SpringApplication.run(AutomatereportsApplication.class, args);
	}

}
