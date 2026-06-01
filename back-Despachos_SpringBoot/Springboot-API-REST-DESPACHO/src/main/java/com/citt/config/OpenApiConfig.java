package com.citt.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import org.springframework.context.annotation.Configuration;

@Configuration
@OpenAPIDefinition(
        info = @Info(
                title = "API REST Despacho",
                version = "1.0",
                description = "API REST para gestionar despachos de productos - Innovatech Chile"
        )
)
public class OpenApiConfig {
}
