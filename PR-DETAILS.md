# Member Lending System

## Overview
This PR introduces a comprehensive member-to-member lending system to the Tokenized Cooperative Savings platform. The feature allows cooperative members to request loans from the shared savings pool based on their contribution history and credit score, creating a decentralized financial lending mechanism with built-in risk management.

## Technical Implementation

### Core Data Structures
- **Enhanced Members Map**: Added loan-related fields including `active-loan-id`, `credit-score`, `total-loans-taken`, `total-interest-paid`, and `last-loan-payment-height`
- **Loans Map**: Complete loan lifecycle tracking with borrower info, amounts, interest rates, payment schedules, and status
- **System Variables**: New tracking variables for `loan-count`, `total-loans-outstanding`, and `total-interest-earned`

### Key Functions Added

#### Loan Management
- `request-loan(amount, duration-blocks)`: Validates eligibility and creates loans with automatic approval
- `make-loan-payment(loan-id, amount)`: Processes payments with interest calculations
- `calculate-loan-eligibility(member)`: Determines loan limits based on contribution history

#### Read-Only Functions  
- `get-loan-info(loan-id)`: Returns complete loan details
- `get-total-loans-outstanding()`: System-wide loan tracking
- `get-loan-count()`: Total number of loans issued

### Risk Management Features

#### Eligibility Requirements
- Minimum contribution threshold (1000 STX)
- Credit score requirement (≥50)
- Single active loan limit per member
- Maximum loan amount: 75% of total contributions

#### Credit Score System
- Base score of 100 for new members
- +2 points per 1000 STX contributed
- +20 bonus points for successful loan completion
- Dynamic scoring affects future loan eligibility

#### Interest and Terms
- Fixed 10% interest rate on all loans
- Duration limits: 144-4320 blocks (1 day - 30 days)
- Flexible repayment: partial and full payments supported
- Automatic status tracking (active → repaid)

### Error Handling
Added 7 new error constants for comprehensive validation:
- `err-loan-not-found` (u111)
- `err-insufficient-credit-score` (u112) 
- `err-loan-limit-exceeded` (u113)
- `err-loan-already-active` (u114)
- `err-payment-amount-invalid` (u115)
- `err-loan-fully-paid` (u116)
- `err-loan-overdue` (u117)

## Testing & Validation

### Contract Validation
- ✅ Contract passes `clarinet check` with no errors
- ✅ All existing functionality preserved
- ✅ Clarity v3 compliant with proper data types
- ✅ Comprehensive error handling implemented

### Test Coverage
- ✅ Member registration and contribution workflows
- ✅ Loan eligibility calculations and validation
- ✅ Loan request and approval processes
- ✅ Payment processing (partial and full)
- ✅ Credit score updates and tracking
- ✅ System statistics and read-only functions
- ✅ Edge cases and error conditions
- ✅ Security validations (authorization, limits)

### CI/CD Pipeline
- ✅ GitHub Actions workflow configured
- ✅ Automated contract syntax validation
- ✅ Test execution on push/PR events
- ✅ Node.js environment setup for testing

## Security Considerations

### Access Controls
- Only borrowers can make payments on their loans
- Member validation required for all loan operations
- Balance verification before fund transfers

### Fund Safety
- Loans limited to available cooperative funds
- Interest calculations prevent over-borrowing
- Automatic status updates maintain data integrity

### Risk Mitigation
- Credit score requirements prevent unlimited borrowing
- Contribution-based loan limits align with member investment
- Duration constraints ensure reasonable repayment periods

## Business Value

### For Members
- Access to capital based on cooperative participation
- Credit building through successful repayments
- Flexible repayment terms and amounts

### For the Cooperative
- New revenue stream through interest payments
- Improved member engagement and retention
- Built-in risk management and lending controls

### System Benefits
- Independent feature with no external dependencies
- Maintains existing cooperative functionality
- Scalable architecture for future enhancements