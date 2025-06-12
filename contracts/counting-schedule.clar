;; Counting Schedule Contract
;; Manages cycle counting schedules and assignments

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SCHEDULE_EXISTS (err u201))
(define-constant ERR_SCHEDULE_NOT_FOUND (err u202))
(define-constant ERR_INVALID_FREQUENCY (err u203))

;; Schedule frequency types
(define-constant FREQUENCY_DAILY u1)
(define-constant FREQUENCY_WEEKLY u7)
(define-constant FREQUENCY_MONTHLY u30)
(define-constant FREQUENCY_QUARTERLY u90)

;; Data structures
(define-map counting-schedules
  { schedule-id: uint }
  {
    location: (string-ascii 100),
    item-category: (string-ascii 50),
    frequency: uint,
    assigned-auditor: principal,
    next-count-date: uint,
    created-at: uint,
    active: bool
  }
)

(define-map schedule-history
  { schedule-id: uint, execution-id: uint }
  {
    executed-at: uint,
    executed-by: principal,
    status: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

(define-data-var next-schedule-id uint u1)
(define-data-var next-execution-id uint u1)

;; Public functions
(define-public (create-schedule
  (location (string-ascii 100))
  (item-category (string-ascii 50))
  (frequency uint)
  (assigned-auditor principal))
  (let ((schedule-id (var-get next-schedule-id)))
    (asserts! (or (is-eq frequency FREQUENCY_DAILY)
                  (is-eq frequency FREQUENCY_WEEKLY)
                  (is-eq frequency FREQUENCY_MONTHLY)
                  (is-eq frequency FREQUENCY_QUARTERLY)) ERR_INVALID_FREQUENCY)
    (map-set counting-schedules
      { schedule-id: schedule-id }
      {
        location: location,
        item-category: item-category,
        frequency: frequency,
        assigned-auditor: assigned-auditor,
        next-count-date: (+ block-height frequency),
        created-at: block-height,
        active: true
      }
    )
    (var-set next-schedule-id (+ schedule-id u1))
    (ok schedule-id)
  )
)

(define-public (execute-count (schedule-id uint) (notes (string-ascii 200)))
  (let ((schedule (unwrap! (map-get? counting-schedules { schedule-id: schedule-id }) ERR_SCHEDULE_NOT_FOUND))
        (execution-id (var-get next-execution-id)))
    (asserts! (is-eq tx-sender (get assigned-auditor schedule)) ERR_UNAUTHORIZED)
    (map-set schedule-history
      { schedule-id: schedule-id, execution-id: execution-id }
      {
        executed-at: block-height,
        executed-by: tx-sender,
        status: "completed",
        notes: notes
      }
    )
    ;; Update next count date
    (map-set counting-schedules
      { schedule-id: schedule-id }
      (merge schedule { next-count-date: (+ block-height (get frequency schedule)) })
    )
    (var-set next-execution-id (+ execution-id u1))
    (ok execution-id)
  )
)

(define-public (reassign-auditor (schedule-id uint) (new-auditor principal))
  (let ((schedule (unwrap! (map-get? counting-schedules { schedule-id: schedule-id }) ERR_SCHEDULE_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set counting-schedules
      { schedule-id: schedule-id }
      (merge schedule { assigned-auditor: new-auditor })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-schedule (schedule-id uint))
  (map-get? counting-schedules { schedule-id: schedule-id })
)

(define-read-only (get-execution-history (schedule-id uint) (execution-id uint))
  (map-get? schedule-history { schedule-id: schedule-id, execution-id: execution-id })
)

(define-read-only (is-count-due (schedule-id uint))
  (match (map-get? counting-schedules { schedule-id: schedule-id })
    schedule (>= block-height (get next-count-date schedule))
    false
  )
)
