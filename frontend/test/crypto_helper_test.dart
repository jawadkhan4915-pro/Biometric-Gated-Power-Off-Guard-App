import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:power_guard/utils/crypto_helper.dart';

void main() {
  group('CryptoHelper Unit Tests', () {
    test('Generate RSA key pair and verify types', () {
      final pair = CryptoHelper.generateKeyPair();
      expect(pair.publicKey, isA<RSAPublicKey>());
      expect(pair.privateKey, isA<RSAPrivateKey>());
      expect(pair.publicKey.modulus, equals(pair.privateKey.modulus));
    });

    test('Encode public key to PEM format', () {
      final pair = CryptoHelper.generateKeyPair();
      final pem = CryptoHelper.encodePublicKeyToPem(pair.publicKey);
      
      expect(pem, startsWith('-----BEGIN PUBLIC KEY-----'));
      expect(pem, endsWith('-----END PUBLIC KEY-----'));
      expect(pem.contains('\n'), isTrue);
    });

    test('Sign payload and verify serialization roundtrip', () {
      final pair = CryptoHelper.generateKeyPair();
      const payload = '{"deviceId":"test_device","timestamp":1700000000,"result":"success"}';
      
      final signature = CryptoHelper.signPayload(pair.privateKey, payload);
      expect(signature, isNotEmpty);
      expect(signature.length, greaterThan(50));

      // Test Private Key roundtrip
      final serializedPriv = CryptoHelper.serializePrivateKey(pair.privateKey);
      final deserializedPriv = CryptoHelper.deserializePrivateKey(serializedPriv);
      expect(deserializedPriv.modulus, equals(pair.privateKey.modulus));
      expect(deserializedPriv.privateExponent, equals(pair.privateKey.privateExponent));

      // Test Public Key roundtrip
      final serializedPub = CryptoHelper.serializePublicKey(pair.publicKey);
      final deserializedPub = CryptoHelper.deserializePublicKey(serializedPub);
      expect(deserializedPub.modulus, equals(pair.publicKey.modulus));
      expect(deserializedPub.exponent, equals(pair.publicKey.exponent));
    });
  });
}
