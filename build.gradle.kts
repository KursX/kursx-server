plugins {
    war
    alias(libs.plugins.jvm)
    alias(libs.plugins.ktor)
    alias(libs.plugins.kotlin.serialization)
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(libs.ktor.server.servlet)
    implementation(libs.bundles.postgres)
    implementation(libs.kotlin.serialization)
}

tasks.war {
    webAppDirectory = File(projectDir, "webapp")
    archiveBaseName.set("ROOT")
    if (File("/opt/tomcat/latest/webapps").exists()) {
        destinationDirectory.set(file("/opt/tomcat/latest/webapps"))
    }
}

sourceSets {
    main {
        kotlin.srcDirs("src")
        resources.srcDirs("resources")
    }
}