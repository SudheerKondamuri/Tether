package com.tether.app.tether

import android.content.Context
import android.util.Log
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.io.ByteArrayInputStream
import java.io.File
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Base64
import java.util.Calendar
import java.util.Date
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/**
 * Manages self-signed TLS certificates for Tether's peer-to-peer connections.
 *
 * Generates RSA-2048 key pairs, creates X.509v3 certificates via Bouncy Castle,
 * persists them as PEM files, and provides [SSLContext] factories for both the
 * server side (own key + cert) and the client/pairing side (trust-all).
 *
 * Fingerprint verification of remote certificates is handled at the application
 * layer during pairing, so the client context intentionally trusts all certs.
 */
object TetherTlsManager {

    private const val TAG = "TetherTls"

    private const val CERTS_DIR = "certs"
    private const val CERT_FILENAME = "tether_cert.pem"
    private const val KEY_FILENAME = "tether_key.pem"

    private const val CERT_PEM_HEADER = "-----BEGIN CERTIFICATE-----"
    private const val CERT_PEM_FOOTER = "-----END CERTIFICATE-----"
    private const val KEY_PEM_HEADER = "-----BEGIN PRIVATE KEY-----"
    private const val KEY_PEM_FOOTER = "-----END PRIVATE KEY-----"

    // ──────────────────────────────────────────────────────────────────────────
    // Public API
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Ensures a valid certificate / key pair exists on disk and returns the two
     * [File] references as **(certFile, keyFile)**.
     *
     * If the PEM files already exist they are returned immediately; otherwise a
     * fresh RSA-2048 key pair and self-signed X.509v3 certificate are generated.
     */
    fun ensureCertificate(context: Context): Pair<File, File> {
        val certsDir = File(context.filesDir, CERTS_DIR)
        val certFile = File(certsDir, CERT_FILENAME)
        val keyFile = File(certsDir, KEY_FILENAME)

        if (certFile.exists() && keyFile.exists()) {
            Log.d(TAG, "Certificate files already exist")
            return Pair(certFile, keyFile)
        }

        Log.i(TAG, "Generating new self-signed certificate")
        generateCertificate(certsDir, certFile, keyFile)
        return Pair(certFile, keyFile)
    }

    /**
     * Creates an [SSLContext] configured as a TLS **server** using the device's
     * own certificate and private key.
     *
     * If loading the stored PEM files fails (e.g. corruption) the files are
     * deleted and a fresh certificate is generated automatically.
     */
    fun createServerSSLContext(context: Context): SSLContext {
        val (certFile, keyFile) = ensureCertificate(context)

        return try {
            buildServerSSLContext(certFile, keyFile)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load certificate, regenerating", e)
            certFile.delete()
            keyFile.delete()
            val (newCertFile, newKeyFile) = ensureCertificate(context)
            buildServerSSLContext(newCertFile, newKeyFile)
        }
    }

    /**
     * Creates an [SSLContext] whose [TrustManager] accepts **all** certificates.
     *
     * This is used during the pairing handshake — certificate fingerprint
     * verification is performed at the application layer instead.
     */
    fun createTrustAllSSLContext(): SSLContext {
        val trustAllManager = object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {
                // Accept all — verified via fingerprint at app layer
            }

            override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {
                // Accept all — verified via fingerprint at app layer
            }

            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
        }

        return try {
            SSLContext.getInstance("TLS").apply {
                init(null, arrayOf<TrustManager>(trustAllManager), SecureRandom())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create trust-all SSLContext", e)
            throw e
        }
    }

    /**
     * Computes the SHA-256 fingerprint of an [X509Certificate].
     *
     * @return Colon-separated lowercase hex, e.g. `aa:bb:cc:dd:…`
     */
    fun fingerprint(cert: X509Certificate): String {
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            val hash = digest.digest(cert.encoded)
            hash.joinToString(":") { byte -> "%02x".format(byte) }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to compute certificate fingerprint", e)
            throw e
        }
    }

    /**
     * Parses a PEM-encoded certificate string and returns its SHA-256
     * fingerprint in colon-separated lowercase hex.
     */
    fun fingerprintFromPem(pemString: String): String {
        val cert = parseCertificateFromPem(pemString)
        return fingerprint(cert)
    }

    /**
     * Loads a PEM-encoded X.509 certificate from [certFile].
     */
    fun loadCertificate(certFile: File): X509Certificate {
        return try {
            val pemContent = certFile.readText()
            parseCertificateFromPem(pemContent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load certificate from ${certFile.absolutePath}", e)
            throw e
        }
    }

    /**
     * Loads a PKCS#8 PEM-encoded RSA private key from [keyFile].
     */
    fun loadPrivateKey(keyFile: File): PrivateKey {
        return try {
            val pemContent = keyFile.readText()
            parsePrivateKeyFromPem(pemContent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load private key from ${keyFile.absolutePath}", e)
            throw e
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Generates an RSA-2048 key pair, builds a self-signed X.509v3 certificate
     * via Bouncy Castle, and writes both to PEM files.
     */
    private fun generateCertificate(certsDir: File, certFile: File, keyFile: File) {
        try {
            if (!certsDir.exists()) {
                certsDir.mkdirs()
            }

            // 1. Generate RSA-2048 key pair
            val keyPairGenerator = KeyPairGenerator.getInstance("RSA")
            keyPairGenerator.initialize(2048, SecureRandom())
            val keyPair = keyPairGenerator.generateKeyPair()

            // 2. Build self-signed X.509v3 certificate with Bouncy Castle
            val issuer = X500Name("CN=tether-device")
            val subject = issuer

            val now = Date()
            val calendar = Calendar.getInstance().apply {
                time = now
                add(Calendar.DAY_OF_YEAR, 365)
            }
            val notAfter = calendar.time

            val serial = BigInteger(128, SecureRandom())

            val certBuilder = JcaX509v3CertificateBuilder(
                issuer,
                serial,
                now,
                notAfter,
                subject,
                keyPair.public
            )

            val contentSigner = JcaContentSignerBuilder("SHA256withRSA")
                .build(keyPair.private)

            val certHolder = certBuilder.build(contentSigner)
            val certificate = JcaX509CertificateConverter().getCertificate(certHolder)

            // 3. Write certificate PEM
            val certBase64 = Base64.getMimeEncoder(64, "\n".toByteArray())
                .encodeToString(certificate.encoded)
            certFile.writeText("$CERT_PEM_HEADER\n$certBase64\n$CERT_PEM_FOOTER\n")

            // 4. Write private key PEM (PKCS#8)
            val keyBase64 = Base64.getMimeEncoder(64, "\n".toByteArray())
                .encodeToString(keyPair.private.encoded)
            keyFile.writeText("$KEY_PEM_HEADER\n$keyBase64\n$KEY_PEM_FOOTER\n")

            Log.i(TAG, "Certificate generated successfully")
            Log.d(TAG, "Fingerprint: ${fingerprint(certificate)}")
        } catch (e: Exception) {
            Log.e(TAG, "Certificate generation failed", e)
            // Clean up partial files
            certFile.delete()
            keyFile.delete()
            throw e
        }
    }

    /**
     * Parses a PEM string into an [X509Certificate].
     */
    private fun parseCertificateFromPem(pemContent: String): X509Certificate {
        val base64 = pemContent
            .replace(CERT_PEM_HEADER, "")
            .replace(CERT_PEM_FOOTER, "")
            .replace("\\s".toRegex(), "")

        val decoded = Base64.getDecoder().decode(base64)
        val factory = CertificateFactory.getInstance("X.509")
        return factory.generateCertificate(ByteArrayInputStream(decoded)) as X509Certificate
    }

    /**
     * Parses a PKCS#8 PEM string into a [PrivateKey].
     */
    private fun parsePrivateKeyFromPem(pemContent: String): PrivateKey {
        val base64 = pemContent
            .replace(KEY_PEM_HEADER, "")
            .replace(KEY_PEM_FOOTER, "")
            .replace("\\s".toRegex(), "")

        val decoded = Base64.getDecoder().decode(base64)
        val keySpec = PKCS8EncodedKeySpec(decoded)
        val keyFactory = KeyFactory.getInstance("RSA")
        return keyFactory.generatePrivate(keySpec)
    }

    /**
     * Builds an [SSLContext] from the given PEM cert and key files, configured
     * for use as a TLS server.
     */
    private fun buildServerSSLContext(certFile: File, keyFile: File): SSLContext {
        val certificate = loadCertificate(certFile)
        val privateKey = loadPrivateKey(keyFile)

        val keyStore = KeyStore.getInstance(KeyStore.getDefaultType()).apply {
            load(null, null)
            setKeyEntry(
                "tether",
                privateKey,
                charArrayOf(),
                arrayOf(certificate)
            )
        }

        val kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm()).apply {
            init(keyStore, charArrayOf())
        }

        return SSLContext.getInstance("TLS").apply {
            init(kmf.keyManagers, null, SecureRandom())
        }
    }
}
