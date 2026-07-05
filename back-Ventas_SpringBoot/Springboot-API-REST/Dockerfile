# =========================================================
# Etapa 1: Compilación (Build Stage)
# Usa Maven + JDK 17 para compilar el microservicio de Ventas
# =========================================================
FROM maven:3.8.8-eclipse-temurin-17 AS build
WORKDIR /app
# Copia primero el pom.xml para aprovechar la caché de capas
COPY pom.xml .
RUN mvn dependency:go-offline
# Luego copia el código fuente y empaqueta (sin tests para acelerar la imagen)
COPY src ./src
RUN mvn clean package -DskipTests

# =========================================================
# Etapa 2: Ejecución ultra-ligera (Principio de mínimo privilegio)
# Solo contiene el JRE, sin Maven ni código fuente
# =========================================================
FROM eclipse-temurin:17-jre

# SEGURIDAD: crear grupo y usuario no-root para ejecutar la app
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

WORKDIR /app

# Copiar el JAR desde la etapa de build
COPY --from=build /app/target/*.jar app.jar

# Asignar propiedad del archivo al usuario no-root y cambiar de usuario
RUN chown appuser:appgroup app.jar
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
