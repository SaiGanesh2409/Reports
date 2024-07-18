package com.reports.automatereports.service;

import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class TillVarianceService {

    private static final String SQL_FILE_PATH = "src/main/resources/queries/TillVarianceReport.sql";

    @Autowired
    private JdbcTemplate jdbcTemplate;

    public void executeQueryAndExportToExcel() throws IOException {
        Path sqlFilePath = Paths.get(SQL_FILE_PATH);
        if (!Files.exists(sqlFilePath)) {
            throw new IOException("SQL file not found: " + SQL_FILE_PATH);
        }

        String query;
        try {
            query = Files.lines(sqlFilePath).collect(Collectors.joining("\n"));
        } catch (IOException e) {
            throw new IOException("Error reading SQL file: " + e.getMessage(), e);
        }

        List<Map<String, Object>> results = jdbcTemplate.queryForList(query);

        Workbook workbook = new XSSFWorkbook();
        Sheet sheet = workbook.createSheet("Results");

        if (!results.isEmpty()) {
            // Create the header row
            Row headerRow = sheet.createRow(0);
            Map<String, Object> firstRow = results.get(0);
            int colNum = 0;
            for (String key : firstRow.keySet()) {
                Cell cell = headerRow.createCell(colNum++);
                cell.setCellValue(key);
                // Apply header cell style if needed
            }

            // Fill data rows
            int rowNum = 1;
            for (Map<String, Object> row : results) {
                Row excelRow = sheet.createRow(rowNum++);
                colNum = 0;
                for (Map.Entry<String, Object> entry : row.entrySet()) {
                    Cell cell = excelRow.createCell(colNum++);
                    if (entry.getValue() instanceof String) {
                        cell.setCellValue((String) entry.getValue());
                    } else if (entry.getValue() instanceof Integer) {
                        cell.setCellValue((Integer) entry.getValue());
                    } else if (entry.getValue() instanceof Double) {
                        cell.setCellValue((Double) entry.getValue());
                    } else if (entry.getValue() instanceof Boolean) {
                        cell.setCellValue((Boolean) entry.getValue());
                    } else if (entry.getValue() != null) {
                        cell.setCellValue(entry.getValue().toString());
                    }
                }
            }
        }

        String date = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd_MMMM_yyyy"));
        String excelFilePath = "src/main/resources/reports/TillVarianceReport_" + date + ".xlsx";

        try (FileOutputStream fileOut = new FileOutputStream(excelFilePath)) {
            workbook.write(fileOut);
        }

        workbook.close();
    }
}
