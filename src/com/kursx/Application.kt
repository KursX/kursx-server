package com.kursx

import io.ktor.http.*
import io.ktor.http.content.*
import java.io.File
import io.ktor.server.application.*
import io.ktor.server.http.content.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.request.*
import io.ktor.utils.io.jvm.javaio.*
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.transactions.transaction

const val FILES_ROOT = "/home"

@Suppress("unused")
fun Application.main() {
    Database.connect("jdbc:postgresql://localhost/demodatabase", user = "ktor", password = "ktor")
    routing {
        get("/") {
            call.respondText { "Home page of the KursX server" }
        }
        // post request with body
        post("/") {
            call.respondText { call.receiveText() }
        }
        // try DOMAIN/database?key=key1
        get("/database/select") {
            val key = call.request.queryParameters["key"]
            val response = transaction {
                if (key == null) {
                    Entity.all()
                } else {
                    Entity.find { Table.key eq key }
                }.joinToString("\n") { it.key + "=" + it.value }
            }
            call.respondText { response }
        }
        // try DOMAIN/database/put?key={key}&value={value}
        get("/database/insert") {
            val key = call.request.queryParameters["key"] ?: return@get call.respond(HttpStatusCode.BadRequest)
            val value = call.request.queryParameters["value"] ?: return@get call.respond(HttpStatusCode.BadRequest)
            val id = transaction {
                Entity.new {
                    this.key = key
                    this.value = value
                }.id.value
            }
            call.respondText { "Inserted id=$id" }
        }
        // try DOMAIN/application.conf to get file from project resources
        staticResources("/resources/application.conf", "application.conf")
        // try DOMAIN/file/demo.txt
        get("/file/{path...}") {
            val filePath = call.parameters.getAll("path").orEmpty()
            if (filePath.isEmpty()) {
                return@get call.respond(HttpStatusCode.BadRequest)
            }
            call.respondFile(File("$FILES_ROOT/${filePath.joinToString("/")}"))
        }
        // store file to /home/{path...} directory
        post("/file/{path...}") {
            val filePath = call.parameters.getAll("path").orEmpty()
            val parent = File("$FILES_ROOT/${filePath.joinToString("/")}")
            if (call.request.isMultipart()) {
                call.receiveMultipart().forEachPart { part ->
                    if (part is PartData.FileItem) {
                        part.provider().toInputStream().use { inputStream ->
                            File(parent, part.name ?: "file").outputStream().buffered().use { outputStream ->
                                inputStream.copyTo(outputStream)
                            }
                        }
                    }
                    part.dispose()
                }
            }
            call.respond(HttpStatusCode.OK)
        }
    }
}