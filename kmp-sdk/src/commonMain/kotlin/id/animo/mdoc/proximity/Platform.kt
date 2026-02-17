package id.animo.mdoc.proximity

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform