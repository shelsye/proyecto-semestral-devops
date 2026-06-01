package com.citt.persistence.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDate;

@Entity
@Data
@AllArgsConstructor
@NoArgsConstructor
public class Despacho {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long idDespacho;

    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate fechaDespacho;

    private String patenteCamion;

    private int intento;

    private Long idCompra;

    private String direccionCompra;

    private Long valorCompra;

    private boolean despachado = false;
}
