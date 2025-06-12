;; Inventory Auditor Verification Contract
;; Manages auditor registration, verification, and permissions

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_AUDITOR_EXISTS (err u101))
(define-constant ERR_AUDITOR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Auditor status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map auditors
  { auditor-id: principal }
  {
    name: (string-ascii 50),
    certification: (string-ascii 100),
    status: uint,
    verified-at: uint,
    verified-by: principal
  }
)

(define-map auditor-stats
  { auditor-id: principal }
  {
    total-counts: uint,
    accurate-counts: uint,
    last-activity: uint
  }
)

;; Public functions
(define-public (register-auditor (name (string-ascii 50)) (certification (string-ascii 100)))
  (let ((auditor-id tx-sender))
    (asserts! (is-none (map-get? auditors { auditor-id: auditor-id })) ERR_AUDITOR_EXISTS)
    (map-set auditors
      { auditor-id: auditor-id }
      {
        name: name,
        certification: certification,
        status: STATUS_PENDING,
        verified-at: u0,
        verified-by: CONTRACT_OWNER
      }
    )
    (map-set auditor-stats
      { auditor-id: auditor-id }
      {
        total-counts: u0,
        accurate-counts: u0,
        last-activity: block-height
      }
    )
    (ok auditor-id)
  )
)

(define-public (verify-auditor (auditor-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? auditors { auditor-id: auditor-id })) ERR_AUDITOR_NOT_FOUND)
    (map-set auditors
      { auditor-id: auditor-id }
      (merge (unwrap-panic (map-get? auditors { auditor-id: auditor-id }))
        {
          status: STATUS_VERIFIED,
          verified-at: block-height,
          verified-by: tx-sender
        }
      )
    )
    (ok true)
  )
)

(define-public (update-auditor-stats (auditor-id principal) (accurate bool))
  (let ((current-stats (default-to
    { total-counts: u0, accurate-counts: u0, last-activity: u0 }
    (map-get? auditor-stats { auditor-id: auditor-id }))))
    (map-set auditor-stats
      { auditor-id: auditor-id }
      {
        total-counts: (+ (get total-counts current-stats) u1),
        accurate-counts: (if accurate
          (+ (get accurate-counts current-stats) u1)
          (get accurate-counts current-stats)),
        last-activity: block-height
      }
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-auditor (auditor-id principal))
  (map-get? auditors { auditor-id: auditor-id })
)

(define-read-only (get-auditor-stats (auditor-id principal))
  (map-get? auditor-stats { auditor-id: auditor-id })
)

(define-read-only (is-verified-auditor (auditor-id principal))
  (match (map-get? auditors { auditor-id: auditor-id })
    auditor (is-eq (get status auditor) STATUS_VERIFIED)
    false
  )
)
