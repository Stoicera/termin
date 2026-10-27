# References only; rendered with `op inject -i deploy/cal/cal.env.tpl` straight into the Dokploy API (like Ghost).
# Item "Termin Cal" (Agents) is created in step 3 of the runbook: db_password (hex 32), nextauth_secret (base64 32),
# encryption_key (base64 24 = 32 chars). "Resend SMTP Termin" comes from C3.
CAL_DB_PASSWORD={{ op://Agents/Termin Cal/db_password }}
CAL_NEXTAUTH_SECRET={{ op://Agents/Termin Cal/nextauth_secret }}
CAL_ENCRYPTION_KEY={{ op://Agents/Termin Cal/encryption_key }}
RESEND_SMTP_PASSWORD={{ op://Agents/Resend SMTP Termin/credential }}
