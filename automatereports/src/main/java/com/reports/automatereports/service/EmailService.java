package com.reports.automatereports.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.InputStreamSource;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStream;

import javax.mail.MessagingException;
import javax.mail.internet.MimeMessage;

@Service
public class EmailService {

    @Autowired
    private JavaMailSender emailSender;

    public void sendEmailWithAttachment(String to,String from, String subject, String body, String[] attachments) throws IOException {
        try {
            MimeMessage message = emailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true);
            helper.setFrom(from);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(body);

            for (String attachment : attachments) {
                ClassPathResource classPathResource = new ClassPathResource(attachment);
                helper.addAttachment(classPathResource.getFilename(), new InputStreamSource() {
                    @Override
                    public InputStream getInputStream() throws IOException {
                        return classPathResource.getInputStream();
                    }
                });
            }

            emailSender.send(message);
            System.out.println("Email sent successfully with attachment!");
        } catch (MessagingException e) {
            System.out.println("Error sending email: " + e.getMessage());
        }
    }
}
