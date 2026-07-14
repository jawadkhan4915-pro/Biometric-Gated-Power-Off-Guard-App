import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/signers/rsa_signer.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/asn1.dart';

class CryptoHelper {
  /// Generates a secure 2048-bit RSA key pair.
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateKeyPair() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator();
    keyGen.init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
      secureRandom,
    ));

    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  /// Encodes an RSA Public Key to SubjectPublicKeyInfo (SPKI) PEM format.
  /// This is compatible with Node's crypto.verify('SHA256') method out-of-the-box.
  static String encodePublicKeyToPem(RSAPublicKey publicKey) {
    // 1. Algorithm Identifier sequence for rsaEncryption OID 1.2.840.113549.1.1.1
    final algorithmSeq = ASN1Sequence();
    algorithmSeq.add(ASN1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1]));
    algorithmSeq.add(ASN1Null());

    // 2. RSA Public Key sequence [modulus, publicExponent]
    final rsaPublicKeySeq = ASN1Sequence();
    rsaPublicKeySeq.add(ASN1Integer(publicKey.modulus));
    rsaPublicKeySeq.add(ASN1Integer(publicKey.exponent));

    // 3. Bit string wrapping the RSA Public Key sequence
    final rsaBitString = ASN1BitString(stringValues: rsaPublicKeySeq.encode());

    // 4. Outer sequence matching SubjectPublicKeyInfo
    final outerSeq = ASN1Sequence();
    outerSeq.add(algorithmSeq);
    outerSeq.add(rsaBitString);

    final bytes = outerSeq.encode();
    final base64Str = base64.encode(bytes);

    // Format PEM to 64 characters per line
    final chunks = <String>[];
    for (var i = 0; i < base64Str.length; i += 64) {
      final end = (i + 64 < base64Str.length) ? i + 64 : base64Str.length;
      chunks.add(base64Str.substring(i, end));
    }

    return "-----BEGIN PUBLIC KEY-----\n${chunks.join('\n')}\n-----END PUBLIC KEY-----";
  }

  /// Signs a text payload using SHA-256 with RSA (PKCS#1 v1.5).
  /// Returns a Base64-encoded signature.
  static String signPayload(RSAPrivateKey privateKey, String payload) {
    // OID for SHA-256 (2.16.840.1.101.3.4.2.1) encoded in hex DER format
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final payloadBytes = utf8.encode(payload) as Uint8List;
    final signature = signer.generateSignature(payloadBytes);
    return base64.encode(signature.bytes);
  }

  /// Helper to serialize an RSAPrivateKey into a secure storage JSON string.
  static String serializePrivateKey(RSAPrivateKey privateKey) {
    return json.encode({
      'modulus': privateKey.modulus.toString(),
      'privateExponent': privateKey.privateExponent.toString(),
      'p': privateKey.p?.toString(),
      'q': privateKey.q?.toString(),
    });
  }

  /// Helper to deserialize an RSAPrivateKey from a secure storage JSON string.
  static RSAPrivateKey deserializePrivateKey(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    return RSAPrivateKey(
      BigInt.parse(data['modulus']),
      BigInt.parse(data['privateExponent']),
      data['p'] != null ? BigInt.parse(data['p']) : null,
      data['q'] != null ? BigInt.parse(data['q']) : null,
    );
  }

  /// Helper to serialize an RSAPublicKey into a storage JSON string.
  static String serializePublicKey(RSAPublicKey publicKey) {
    return json.encode({
      'modulus': publicKey.modulus.toString(),
      'exponent': publicKey.exponent.toString(),
    });
  }

  /// Helper to deserialize an RSAPublicKey from a storage JSON string.
  static RSAPublicKey deserializePublicKey(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    return RSAPublicKey(
      BigInt.parse(data['modulus']),
      BigInt.parse(data['exponent']),
    );
  }
}
