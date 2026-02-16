package id.animo.mdoc.proximity

class Logic {
    fun greet(): String {
        return "Hello, ${platform()}!"
    }
}

expect fun platform(): String
