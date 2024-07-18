package com.reports.automatereports.service;

import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.util.StreamUtils;

import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

@Service
public class SmartSafeTreasuryService {

    private static final String SQL_FILE_PATH = "queries/SmartSafeTreasury.sql";

    @Autowired
    private JdbcTemplate jdbcTemplate;

    public void executeQueryAndExportToExcel() throws IOException {
        String query = readSqlQueryFromFile(SQL_FILE_PATH);

        String modifiedDate = LocalDateTime.now().minusDays(2).format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
        query = query.replace("${REPORT_DATE}", modifiedDate);

        
        // Execute query
        List<Map<String, Object>> results = jdbcTemplate.queryForList(query);

        // Create Excel workbook and sheet
        Workbook workbook = new XSSFWorkbook();
        Sheet sheet = workbook.createSheet("Results");

        // Write results to Excel
        if (!results.isEmpty()) {
            // Create header row
            Row headerRow = sheet.createRow(0);
            Map<String, Object> firstRow = results.get(0);
            int colNum = 0;
            for (String key : firstRow.keySet()) {
                Cell cell = headerRow.createCell(colNum++);
                cell.setCellValue(key);
            }

            // Fill data rows
            int rowNum = 1;
            for (Map<String, Object> row : results) {
                Row excelRow = sheet.createRow(rowNum++);
                colNum = 0;
                for (Object value : row.values()) {
                    Cell cell = excelRow.createCell(colNum++);
                    if (value instanceof String) {
                        cell.setCellValue((String) value);
                    } else if (value instanceof Integer) {
                        cell.setCellValue((Integer) value);
                    } else if (value instanceof Double) {
                        cell.setCellValue((Double) value);
                    } else if (value instanceof Boolean) {
                        cell.setCellValue((Boolean) value);
                    } else if (value instanceof java.sql.Date) {
                        cell.setCellValue(value.toString());
                    } else if (value != null) {
                        cell.setCellValue(value.toString());
                    }
                }
            }
        } else {
            // If no results, write a message to the Excel file
            Row headerRow = sheet.createRow(0);
            Cell cell = headerRow.createCell(0);
            cell.setCellValue("No data available for the selected date.");

            // Adjust column width for the message cell
            sheet.autoSizeColumn(0);
        }

        // Generate file path with current date
        String date = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd_MMMM_yyyy"));
        String excelFilePath = "src/main/resources/reports/SmartSafeTreasuryReport_" + date + ".xlsx";

        try (FileOutputStream fileOut = new FileOutputStream(excelFilePath)) {
            workbook.write(fileOut);
        }

        workbook.close();
    }

    private String readSqlQueryFromFile(String filePath) throws IOException {
        ClassPathResource resource = new ClassPathResource(filePath);
        byte[] bytes = StreamUtils.copyToByteArray(resource.getInputStream());
        return new String(bytes, StandardCharsets.UTF_8);
    }
}
