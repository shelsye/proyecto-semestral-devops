# =========================================================
# Etapa 1: Compilación (Build Stage)
# Usa Maven + JDK para compilar el proyecto
# =========================================================
FROM maven:3.8.8-eclipse-temurin-17 AS build
WORKDIR /app
# Copia solo el pom.xml primero para aprovechar caché de capas
COPY pom.xml .
RUN mvn dependency:go-offline
# Luego copia el código fuente
COPY src ./src
RUN mvn clean package -DskipTests

# =========================================================
# Etapa 2: Ejecución ultra-ligera (Principio de mínimo privilegio)
# Solo contiene el JRE, sin Maven ni código fuente
# =========================================================
FROM eclipse-temurin:17-jre

# SEGURIDAD: crear un grupo y usuario no-root para ejecutar la app
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

WORKDIR /app

# Copiar el JAR desde la etapa de build
COPY --from=build /app/target/*.jar app.jar

# Asignar propiedad del archivo al usuario no-root
RUN chown appuser:appgroup app.jar

# Cambiar al usuario no-root antes de ejecutar
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
