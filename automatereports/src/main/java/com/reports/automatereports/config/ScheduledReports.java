package com.reports.automatereports.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.reports.automatereports.service.ACHCheckTransactionReport;
import com.reports.automatereports.service.ChangeFundService;
import com.reports.automatereports.service.KioskReconcileService;
import com.reports.automatereports.service.SmartSafeTreasuryService;
import com.reports.automatereports.service.TillVarianceService;
import com.reports.automatereports.service.TreasuryService;

import java.io.IOException;

@Component
public class ScheduledReports {

    private static final Logger logger = LoggerFactory.getLogger(ScheduledReports.class);

    @Autowired
    private TillVarianceService tillVarianceService;

    @Autowired
    private KioskReconcileService kioskReconcileService;

    @Autowired
    private ChangeFundService changeFundService;

    @Autowired
    private TreasuryService treasuryService;

    @Autowired
    private SmartSafeTreasuryService smartSafeTreasuryService;

    @Autowired
    private ACHCheckTransactionReport aCHCheckTransactionReport;

    @Async
    @Scheduled(cron = "${scheduled.tasks.daily.cron}")
    public void generateDailyReports() {
        StringBuilder message = new StringBuilder();

        try {
            tillVarianceService.executeQueryAndExportToExcel();
            message.append("Till Variance Report exported successfully! ");
        } catch (IOException e) {
            logger.error("Error exporting Till Variance Report: {}", e.getMessage(), e);
            message.append("Error exporting Till Variance Report: ").append(e.getMessage()).append(" ");
        }

        try {
            changeFundService.executeQueryAndExportToExcel();
            message.append("Change Fund Report exported successfully! ");
        } catch (IOException e) {
            logger.error("Error exporting Change Fund Report: {}", e.getMessage(), e);
            message.append("Error exporting Change Fund Report: ").append(e.getMessage()).append(" ");
        }

        try {
            kioskReconcileService.executeQueryAndExportToExcel();
            message.append("Kiosk Reconcile Report exported successfully! ");
        } catch (IOException e) {
            logger.error("Error exporting Kiosk Reconcile Report: {}", e.getMessage(), e);
            message.append("Error exporting Kiosk Reconcile Report: ").append(e.getMessage()).append(" ");
        }

        try {
            treasuryService.executeQueryAndExportToExcel();
            message.append("Treasury Report exported successfully! ");
        } catch (IOException e) {
            logger.error("Error exporting Treasury Report: {}", e.getMessage(), e);
            message.append("Error exporting Treasury Report: ").append(e.getMessage()).append(" ");
        }

        try {
            smartSafeTreasuryService.executeQueryAndExportToExcel();
            message.append("Smart Safe Treasury Report exported successfully! ");
        } catch (IOException e) {
            logger.error("Error exporting Smart Safe Treasury Report: {}", e.getMessage(), e);
            message.append("Error exporting Smart Safe Treasury Report: ").append(e.getMessage()).append(" ");
        }

        logger.info(message.toString().trim());
    }

    @Async
    @Scheduled(cron = "${scheduled.tasks.weekly.cron}")
    public void generateWeeklyReports() {
        StringBuilder message = new StringBuilder();

        try {
            aCHCheckTransactionReport.executeQueryAndExportToExcel();
            message.append("ACH Check Transaction Report exported successfully! ");
        } catch (IOException e) {
            logger.error("Error exporting ACH Check Transaction Report: {}", e.getMessage(), e);
            message.append("Error exporting ACH Check Transaction Report: ").append(e.getMessage()).append(" ");
        }

        logger.info(message.toString().trim());
    }
}
