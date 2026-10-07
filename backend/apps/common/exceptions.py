class ERPException(Exception):
    """Base exception for ERP platform errors."""
    code = "INTERNAL_ERROR"
    message = "An error occurred."

    def __init__(self, message=None, code=None, extensions=None):
        super().__init__(message or self.message)
        if message:
            self.message = message
        if code:
            self.code = code
        self.extensions = extensions or {}


class AuthenticationRequiredError(ERPException):
    code = "UNAUTHENTICATED"
    message = "Authentication credentials were not provided or are invalid."


class TenantNotFoundError(ERPException):
    code = "TENANT_NOT_FOUND"
    message = "Requested business tenant does not exist or user is not a member."


class PermissionDeniedError(ERPException):
    code = "FORBIDDEN"
    message = "You do not have permission to perform this action."

    def __init__(self, permission_code: str, message: str = None):
        msg = message or f"Permission denied. Required permission: '{permission_code}'"
        super().__init__(message=msg, code="FORBIDDEN", extensions={"permissionRequired": permission_code})


class ValidationError(ERPException):
    code = "VALIDATION_ERROR"
    message = "One or more input fields failed validation."


class ConflictError(ERPException):
    code = "CONFLICT"
    message = "A concurrency conflict occurred. The resource was modified by another operation."
