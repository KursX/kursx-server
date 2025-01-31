package com.kursx

import org.jetbrains.exposed.dao.IntEntity
import org.jetbrains.exposed.dao.IntEntityClass
import org.jetbrains.exposed.dao.id.EntityID
import org.jetbrains.exposed.dao.id.IntIdTable

object Table : IntIdTable("demotable") {

    val key = text("key")
    val value = text("value")
}


class Entity(id: EntityID<Int>) : IntEntity(id) {

    companion object : IntEntityClass<Entity>(Table)

    var key by Table.key
    var value by Table.value
}