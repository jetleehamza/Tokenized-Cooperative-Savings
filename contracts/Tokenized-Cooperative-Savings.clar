(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-proposal-not-found (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-proposal-expired (err u105))
(define-constant err-already-member (err u106))
(define-constant err-proposal-already-executed (err u107))
(define-constant err-invalid-amount (err u108))
(define-constant err-transfer-failed (err u109))
(define-constant err-unauthorized (err u110))
(define-constant err-loan-not-found (err u111))
(define-constant err-insufficient-credit-score (err u112))
(define-constant err-loan-limit-exceeded (err u113))
(define-constant err-loan-already-active (err u114))
(define-constant err-payment-amount-invalid (err u115))
(define-constant err-loan-fully-paid (err u116))
(define-constant err-loan-overdue (err u117))

(define-data-var total-savings uint u0)
(define-data-var member-count uint u0)
(define-data-var proposal-count uint u0)
(define-data-var loan-count uint u0)
(define-data-var total-loans-outstanding uint u0)
(define-data-var total-interest-earned uint u0)

(define-map members
    principal
    {
        balance: uint,
        joined-height: uint,
        total-contributed: uint,
        active-loan-id: (optional uint),
        credit-score: uint,
        total-loans-taken: uint,
        total-interest-paid: uint,
        last-loan-payment-height: uint,
    }
)

(define-map proposals
    uint
    {
        proposer: principal,
        amount: uint,
        description: (string-ascii 256),
        yes-votes: uint,
        no-votes: uint,
        executed: bool,
        deadline: uint,
        voters: (list 50 principal),
    }
)

(define-map loans
    uint
    {
        borrower: principal,
        amount: uint,
        interest-rate: uint,
        remaining-balance: uint,
        total-interest: uint,
        start-height: uint,
        duration-blocks: uint,
        payment-due-height: uint,
        payments-made: uint,
        status: (string-ascii 20),
    }
)

(define-read-only (get-member-info (member principal))
    (default-to {
        balance: u0,
        joined-height: u0,
        total-contributed: u0,
        active-loan-id: none,
        credit-score: u0,
        total-loans-taken: u0,
        total-interest-paid: u0,
        last-loan-payment-height: u0,
    }
        (map-get? members member)
    )
)

(define-read-only (get-proposal (id uint))
    (map-get? proposals id)
)

(define-read-only (get-total-savings)
    (var-get total-savings)
)

(define-read-only (get-member-count)
    (var-get member-count)
)

(define-read-only (get-loan-info (loan-id uint))
    (map-get? loans loan-id)
)

(define-read-only (get-total-loans-outstanding)
    (var-get total-loans-outstanding)
)

(define-read-only (get-loan-count)
    (var-get loan-count)
)

(define-read-only (calculate-loan-eligibility (member principal))
    (let (
            (member-data (get-member-info member))
            (contribution (get total-contributed member-data))
            (credit-score (get credit-score member-data))
            (has-active-loan (is-some (get active-loan-id member-data)))
            (max-loan-amount (/ (* contribution u3) u4))
        )
        {
            eligible: (and
                (> contribution u1000)
                (>= credit-score u50)
                (not has-active-loan)
            ),
            max-amount: max-loan-amount,
            current-score: credit-score,
        }
    )
)

(define-public (join-cooperative)
    (let ((height burn-block-height))
        (asserts! (is-none (map-get? members tx-sender)) err-already-member)
        (map-set members tx-sender {
            balance: u0,
            joined-height: height,
            total-contributed: u0,
            active-loan-id: none,
            credit-score: u100,
            total-loans-taken: u0,
            total-interest-paid: u0,
            last-loan-payment-height: u0,
        })
        (var-set member-count (+ (var-get member-count) u1))
        (ok true)
    )
)

(define-public (contribute (amount uint))
    (let (
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (new-balance (+ (get balance member-data) amount))
            (new-total-contributed (+ (get total-contributed member-data) amount))
            (credit-boost (/ amount u500))
        )
        (asserts! (> amount u0) err-invalid-amount)
        ;; For testing, we'll skip the actual STX transfer
        (map-set members tx-sender {
            balance: new-balance,
            joined-height: (get joined-height member-data),
            total-contributed: new-total-contributed,
            active-loan-id: (get active-loan-id member-data),
            credit-score: (+ (get credit-score member-data) credit-boost),
            total-loans-taken: (get total-loans-taken member-data),
            total-interest-paid: (get total-interest-paid member-data),
            last-loan-payment-height: (get last-loan-payment-height member-data),
        })
        (var-set total-savings (+ (var-get total-savings) amount))
        (ok true)
    )
)

(define-public (create-proposal
        (amount uint)
        (description (string-ascii 256))
    )
    (let (
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (proposal-id (+ (var-get proposal-count) u1))
            (deadline (+ burn-block-height u144))
        )
        (asserts! (<= amount (var-get total-savings)) err-insufficient-balance)
        (map-set proposals proposal-id {
            proposer: tx-sender,
            amount: amount,
            description: description,
            yes-votes: u0,
            no-votes: u0,
            executed: false,
            deadline: deadline,
            voters: (list),
        })
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal
        (proposal-id uint)
        (vote bool)
    )
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (voters (get voters proposal))
        )
        (asserts! (< burn-block-height (get deadline proposal))
            err-proposal-expired
        )
        (asserts! (is-none (index-of voters tx-sender)) err-already-voted)
        (map-set proposals proposal-id
            (merge proposal {
                yes-votes: (if vote
                    (+ (get yes-votes proposal) u1)
                    (get yes-votes proposal)
                ),
                no-votes: (if vote
                    (get no-votes proposal)
                    (+ (get no-votes proposal) u1)
                ),
                voters: (unwrap! (as-max-len? (append voters tx-sender) u50)
                    err-owner-only
                ),
            })
        )
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        )
        (asserts! (>= burn-block-height (get deadline proposal))
            err-proposal-expired
        )
        (asserts! (not (get executed proposal)) err-proposal-already-executed)
        (asserts! (> (get yes-votes proposal) (get no-votes proposal))
            err-invalid-amount
        )
        ;; For testing, skip the STX transfer
        (map-set proposals proposal-id (merge proposal { executed: true }))
        (var-set total-savings (- (var-get total-savings) (get amount proposal)))
        (ok true)
    )
)

(define-public (withdraw (amount uint))
    (let (
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (current-balance (get balance member-data))
        )
        (asserts! (>= current-balance amount) err-insufficient-balance)
        ;; For testing, skip the STX transfer
        (map-set members tx-sender
            (merge member-data { balance: (- current-balance amount) })
        )
        (var-set total-savings (- (var-get total-savings) amount))
        (ok true)
    )
)

(define-public (request-loan
        (amount uint)
        (duration-blocks uint)
    )
    (let (
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (eligibility (calculate-loan-eligibility tx-sender))
            (loan-id (+ (var-get loan-count) u1))
            (interest-rate u10)
            (total-interest (/ (* amount interest-rate) u100))
            (available-funds (- (var-get total-savings) (var-get total-loans-outstanding)))
        )
        (asserts! (get eligible eligibility) err-insufficient-credit-score)
        (asserts! (<= amount (get max-amount eligibility))
            err-loan-limit-exceeded
        )
        (asserts! (is-none (get active-loan-id member-data))
            err-loan-already-active
        )
        (asserts! (<= amount available-funds) err-insufficient-balance)
        (asserts! (and (>= duration-blocks u144) (<= duration-blocks u4320))
            err-payment-amount-invalid
        )

        ;; For testing, skip the STX transfer
        (map-set loans loan-id {
            borrower: tx-sender,
            amount: amount,
            interest-rate: interest-rate,
            remaining-balance: (+ amount total-interest),
            total-interest: total-interest,
            start-height: burn-block-height,
            duration-blocks: duration-blocks,
            payment-due-height: (+ burn-block-height duration-blocks),
            payments-made: u0,
            status: "active",
        })

        (map-set members tx-sender
            (merge member-data {
                active-loan-id: (some loan-id),
                total-loans-taken: (+ (get total-loans-taken member-data) u1),
            })
        )

        (var-set loan-count loan-id)
        (var-set total-loans-outstanding
            (+ (var-get total-loans-outstanding) (+ amount total-interest))
        )
        (ok loan-id)
    )
)

(define-public (make-loan-payment
        (loan-id uint)
        (amount uint)
    )
    (let (
            (loan (unwrap! (map-get? loans loan-id) err-loan-not-found))
            (member-data (unwrap! (map-get? members tx-sender) err-not-member))
            (remaining (get remaining-balance loan))
        )
        (asserts! (is-eq (get borrower loan) tx-sender) err-owner-only)
        (asserts! (is-eq (get status loan) "active") err-loan-fully-paid)
        (asserts! (> amount u0) err-payment-amount-invalid)
        (asserts! (<= amount remaining) err-payment-amount-invalid)

        ;; For testing, skip the STX transfer
        (let (
                (new-remaining (- remaining amount))
                (is-fully-paid (is-eq new-remaining u0))
                (interest-portion (if (> amount (get total-interest loan))
                    (get total-interest loan)
                    amount
                ))
            )
            (map-set loans loan-id
                (merge loan {
                    remaining-balance: new-remaining,
                    payments-made: (+ (get payments-made loan) u1),
                    status: (if is-fully-paid
                        "repaid"
                        "active"
                    ),
                })
            )

            (if is-fully-paid
                (map-set members tx-sender
                    (merge member-data {
                        active-loan-id: none,
                        credit-score: (+ (get credit-score member-data) u20),
                        total-interest-paid: (+ (get total-interest-paid member-data) interest-portion),
                        last-loan-payment-height: burn-block-height,
                    })
                )
                (map-set members tx-sender
                    (merge member-data {
                        total-interest-paid: (+ (get total-interest-paid member-data) interest-portion),
                        last-loan-payment-height: burn-block-height,
                    })
                )
            )

            (var-set total-loans-outstanding
                (- (var-get total-loans-outstanding) amount)
            )
            (var-set total-interest-earned
                (+ (var-get total-interest-earned) interest-portion)
            )
            (var-set total-savings (+ (var-get total-savings) amount))
            (ok new-remaining)
        )
    )
)

(define-read-only (get-dashboard (who principal))
    (let (
            (member-raw (map-get? members who))
            (member-data (default-to {
                balance: u0,
                joined-height: u0,
                total-contributed: u0,
                active-loan-id: none,
                credit-score: u0,
                total-loans-taken: u0,
                total-interest-paid: u0,
                last-loan-payment-height: u0,
            }
                member-raw
            ))
            (is-member (is-some member-raw))
            (active-id (get active-loan-id member-data))
        )
        {
            totals: {
                total-savings: (var-get total-savings),
                member-count: (var-get member-count),
                proposal-count: (var-get proposal-count),
                loan-count: (var-get loan-count),
                total-loans-outstanding: (var-get total-loans-outstanding),
                total-interest-earned: (var-get total-interest-earned),
            },
            member: {
                is-member: is-member,
                balance: (get balance member-data),
                credit-score: (get credit-score member-data),
                total-contributed: (get total-contributed member-data),
                active-loan-id: active-id,
                last-loan-payment-height: (get last-loan-payment-height member-data),
                joined-height: (get joined-height member-data),
            },
            loan: (match active-id
                loan-id (match (map-get? loans loan-id)
                    loan-data (some {
                        id: loan-id,
                        remaining-balance: (get remaining-balance loan-data),
                        payment-due-height: (get payment-due-height loan-data),
                        status: (get status loan-data),
                    })
                    none
                )
                none
            ),
        }
    )
)
