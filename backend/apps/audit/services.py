from .models import AuditLog


def log_audit_event(
    action: str,
    entity_type: str,
    entity_id: str,
    business=None,
    user=None,
    old_values=None,
    new_values=None,
    ip_address=None,
    user_agent=""
) -> AuditLog:
    """
    Safely creates an immutable audit trail entry.
    """
    return AuditLog.objects.create(
        business=business,
        user=user if user and user.is_authenticated else None,
        action=action,
        entity_type=entity_type,
        entity_id=str(entity_id),
        old_values=old_values or {},
        new_values=new_values or {},
        ip_address=ip_address,
        user_agent=user_agent or "",
    )
