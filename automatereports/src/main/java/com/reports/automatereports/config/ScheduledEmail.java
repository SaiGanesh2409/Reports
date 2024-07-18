package com.reports.automatereports.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.reports.automatereports.service.EmailService;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@Component
public class ScheduledEmail {

    private static final Logger logger = LoggerFactory.getLogger(ScheduledEmail.class);

    @Autowired
    private EmailService emailService;

    // Daily email properties
    @Value("${daily.email.from}")
    private String dailyFrom;

    @Value("${daily.email.to}")
    private String dailyTo;

    @Value("${daily.email.subject.prefix}")
    private String dailySubjectPrefix;

    @Value("${daily.email.body.template}")
    private String dailyBodyTemplate;

    // Weekly email properties
    @Value("${weekly.email.from}")
    private String weeklyFrom;

    @Value("${weekly.email.to}")
    private String weeklyTo;

    @Value("${weekly.email.subject.prefix}")
    private String weeklySubjectPrefix;

    @Value("${weekly.email.body.template}")
    private String weeklyBodyTemplate;

    @Async
    @Scheduled(cron = "${scheduled.tasks.daily.cron}")
    public void sendEmailWithDailyReports() {
        String sysDate = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd_MMMM_yyyy"));
        String twoDaysBackDate = LocalDateTime.now().minusDays(2).format(DateTimeFormatter.ofPattern("dd_MMMM_yyyy"));

        String subject = dailySubjectPrefix + " " + sysDate;
        String body = dailyBodyTemplate.replace("{date}", twoDaysBackDate);
        String[] attachments = {
            "reports/KioskReconcileReport_" + sysDate + ".xlsx",
            "reports/ChangeFundReport_" + sysDate + ".xlsx",
            "reports/SmartSafeTreasuryReport_" + sysDate + ".xlsx",
            "reports/TreasuryReport_" + sysDate + ".xlsx"
        };

        try {
            emailService.sendEmailWithAttachment(dailyTo, dailyFrom, subject, body, attachments);
            logger.info("Daily email sent with attachments!");
        } catch (IOException e) {
            logger.error("Error sending daily email with attachments: {}", e.getMessage(), e);
        }
    }

    @Async
    @Scheduled(cron = "${scheduled.tasks.weekly.cron}")
    public void sendEmailWithWeeklyReports() {
        String sysDate = LocalDateTime.now().format(DateTimeFormatter.ofPattern("MMMM_yyyy"));
        String startDate = LocalDateTime.now().minusDays(8).format(DateTimeFormatter.ofPattern("dd_MMMM_yyyy"));
        String endDate = LocalDateTime.now().minusDays(2).format(DateTimeFormatter.ofPattern("dd_MMMM_yyyy"));

        String subject = weeklySubjectPrefix;
        String body = weeklyBodyTemplate.replace("{start_date}", startDate).replace("{end_date}", endDate);
        String[] attachments = {
            "reports/ACH_CheckTransactionReport_" + sysDate + ".xlsx"
        };

        try {
            emailService.sendEmailWithAttachment(weeklyTo,dailyFrom, subject, body, attachments);
            logger.info("Weekly email sent with attachments!");
        } catch (IOException e) {
            logger.error("Error sending weekly email with attachments: {}", e.getMessage(), e);
        }
    }
}
