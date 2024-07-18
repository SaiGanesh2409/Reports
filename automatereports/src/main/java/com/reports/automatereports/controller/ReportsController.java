package com.reports.automatereports.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import com.reports.automatereports.config.ScheduledEmail;
import com.reports.automatereports.config.ScheduledReports;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@RestController
public class ReportsController {

	@Autowired
	private ScheduledReports scheduledReports;

	@Autowired
	private ScheduledEmail scheduledEmail;

	@GetMapping("/testScheduledTasks")
	public String testScheduledTasks() {
		StringBuilder result = new StringBuilder();

		scheduledReports.generateDailyReports();
		result.append("Scheduled Daily report generation task executed successfully. ");

		/*scheduledReports.generateWeeklyReports();
		result.append("Scheduled Weekly report generation task executed successfully. ");*/

		return result.toString();
	}

	@GetMapping("/sendTestEmail")
	public String sendTestEmail() throws IOException {
		// Simulate sending a test email for both daily and weekly emails
		scheduledEmail.sendEmailWithDailyReports();
		//scheduledEmail.sendEmailWithWeeklyReports();
		return "Test emails sent successfully.";
	}
}
