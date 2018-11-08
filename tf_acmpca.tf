/*
https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html
Create CA Key

Have an openssl.cnf file  with atleast:

[ v3_ca ]
# Extensions for a typical CA (`man x509v3_config`).
basicConstraints = critical,CA:TRUE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
keyUsage = cRLSign, keyCertSign


openssl genrsa -out ca_sandbox_zavasrv_internal.key 4096
openssl req -config openssl.cnf -new -x509 -subj "/C=GB/L=London/O=Zava/CN=sandbox.zavasrv.internal" -extensions v3_ca  -key ca_sandbox_zavasrv_internal.key -out ca_sandbox_zavasrv_internal.crt



Download CSR from acmpca
Verify:
openssl req -verify -in acmpca.csr -text -noout

Create v3 extensions file:  v3-ca.ext

basicConstraints = critical,CA:TRUE
subjectKeyIdentifier = hash
authorityKeyIdentifier  = keyid:always,issuer
keyUsage = cRLSign, keyCertSign


Sign:
openssl x509  -req -days 1095 -in acmpca.csr -CA ca_sandbox_zavasrv_internal.crt -extfile v3-ca.ext -CAkey ca_sandbox_zavasrv_internal.key -CAcreateserial -out acmpca.crt

Import:

aws acm-pca import-certificate-authority-certificate  --certificate-authority-arn arn:aws:acm-pca:eu-west-1:038510939644:certificate-authority/b76fa488-7c69-4bc7-891d-5f76e6387cec --certificate file://acmpca.crt --certificate-chain file://ca_sandbox_zavasrv_internal.crt
*/

/* Server Side

Add the permission to the ec2 instance: aws_iam_policy.acm_pca_server_policy.arn

https://docs.aws.amazon.com/acm-pca/latest/userguide/PcaIssueCert.html

HOSTNAME=server2
DOMAIN=sandbox.zavasrv.internal
CA_ARN=arn:aws:acm-pca:eu-west-1:038510939644:certificate-authority/b76fa488-7c69-4bc7-891d-5f76e6387cec
openssl genrsa -out ${HOSTNAME}.key 4096
openssl req -new -days 365 -key ${HOSTNAME}.key -out ${HOSTNAME}.csr -subj "/C=GB/L=London/O=Zava/CN=${HOSTNAME}.${DOMAIN}"

CERT_ARN=$(aws acm-pca issue-certificate \
--certificate-authority-arn $CA_ARN \
--csr file://${HOSTNAME}.csr \
--signing-algorithm "SHA256WITHRSA" \
--validity Value=365,Type="DAYS" \
--idempotency-token $HOSTNAME \
--output text)

sleep 1

aws acm-pca get-certificate \
--certificate-authority-arn $CA_ARN \
--certificate-arn $CERT_ARN \
--output text  > $HOSTNAME.crt

aws acm-pca get-certificate-authority-certificate \
--certificate-authority-arn $CA_ARN \
--output text > ca.crt
*/

resource "aws_s3_bucket" "snd_crl_bucket" {
  bucket = "crl-${replace(var.route53_dns_internal_zones["sandbox"],".","-")}"
  acl    = "private"
}

data "aws_iam_policy_document" "acmpca_bucket_access" {
  statement {
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = [
      "${aws_s3_bucket.snd_crl_bucket.arn}",
      "${aws_s3_bucket.snd_crl_bucket.arn}/*",
    ]

    principals {
      identifiers = ["acm-pca.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_s3_bucket_policy" "snd_crl_bucket" {
  bucket = "${aws_s3_bucket.snd_crl_bucket.id}"
  policy = "${data.aws_iam_policy_document.acmpca_bucket_access.json}"
}

resource "aws_acmpca_certificate_authority" "private_ca" {
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name  = "${var.route53_dns_internal_zones["sandbox"]}"
      country      = "GB"
      locality     = "London"
      organization = "Zava"
    }
  }

  revocation_configuration {
    crl_configuration {
      custom_cname       = "crl.${var.route53_dns_internal_zones["sandbox"]}"
      enabled            = true
      expiration_in_days = 7
      s3_bucket_name     = "${aws_s3_bucket.snd_crl_bucket.id}"
    }
  }

  depends_on = ["aws_s3_bucket_policy.snd_crl_bucket"]
}

data "aws_iam_policy_document" "acm_pca_server_policy" {
  statement {
    sid = "1"

    actions = [
      "acm-pca:ListCertificateAuthorities",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "2"

    actions = [
      "acm-pca:DescribeCertificateAuthority",
      "acm-pca:DescribeCertificateAuthorityAuditReport",
      "acm-pca:ListTags",
      "acm-pca:GetCertificateAuthorityCertificate",
      "acm-pca:GetCertificateAuthorityCsr",
      "acm-pca:GetCertificate",
      "acm-pca:IssueCertificate",
    ]

    resources = ["${aws_acmpca_certificate_authority.private_ca.arn}"]
  }
}

resource "aws_iam_policy" "acm_pca_server_policy" {
  name   = "acm_pca_server_policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.acm_pca_server_policy.json}"
}
