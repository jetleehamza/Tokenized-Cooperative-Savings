import { describe, expect, it, beforeEach } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const contractName = "Tokenized-Cooperative-Savings";

describe("Loan System Tests", () => {
  beforeEach(() => {
    simnet.mineEmptyBlocks(1);
  });

  it("allows members to join and contribute", () => {
    // Member joins cooperative
    const joinResult = simnet.callPublicFn(
      contractName,
      "join-cooperative",
      [],
      wallet1
    );
    expect(joinResult.result).toBeOk();

    // Member contributes funds
    const contributeResult = simnet.callPublicFn(
      contractName,
      "contribute",
      ["u5000"],
      wallet1
    );
    expect(contributeResult.result).toBeOk();
  });

  it("calculates loan eligibility correctly", () => {
    // Setup member
    simnet.callPublicFn(contractName, "join-cooperative", [], wallet1);
    simnet.callPublicFn(contractName, "contribute", ["u5000"], wallet1);

    // Check eligibility
    const eligibilityResult = simnet.callReadOnlyFn(
      contractName,
      "calculate-loan-eligibility",
      [`'${wallet1}`],
      wallet1
    );
    
    const eligibility = eligibilityResult.result.expectTuple();
    expect(eligibility.eligible).toBe(true);
  });

  it("allows eligible members to request loans", () => {
    // Setup member
    simnet.callPublicFn(contractName, "join-cooperative", [], wallet1);
    simnet.callPublicFn(contractName, "contribute", ["u5000"], wallet1);

    // Request loan
    const loanResult = simnet.callPublicFn(
      contractName,
      "request-loan",
      ["u2000", "u1000"],
      wallet1
    );
    
    expect(loanResult.result).toBeOk();
  });

  it("allows borrowers to make payments", () => {
    // Setup member and loan
    simnet.callPublicFn(contractName, "join-cooperative", [], wallet1);
    simnet.callPublicFn(contractName, "contribute", ["u5000"], wallet1);
    simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], wallet1);

    // Make payment
    const paymentResult = simnet.callPublicFn(
      contractName,
      "make-loan-payment",
      ["u1", "u500"],
      wallet1
    );
    
    expect(paymentResult.result).toBeOk();
  });

  it("tracks loan information correctly", () => {
    // Setup member and loan
    simnet.callPublicFn(contractName, "join-cooperative", [], wallet1);
    simnet.callPublicFn(contractName, "contribute", ["u5000"], wallet1);
    simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], wallet1);

    // Get loan info
    const loanInfoResult = simnet.callReadOnlyFn(
      contractName,
      "get-loan-info",
      ["u1"],
      wallet1
    );
    
    expect(loanInfoResult.result).toBeSome();
  });

  it("prevents non-members from requesting loans", () => {
    const loanResult = simnet.callPublicFn(
      contractName,
      "request-loan",
      ["u1000", "u1000"],
      wallet2
    );
    
    expect(loanResult.result).toBeErr();
  });

  it("prevents loans exceeding contribution limits", () => {
    // Setup member with small contribution
    simnet.callPublicFn(contractName, "join-cooperative", [], wallet1);
    simnet.callPublicFn(contractName, "contribute", ["u1000"], wallet1);

    // Try to request large loan
    const loanResult = simnet.callPublicFn(
      contractName,
      "request-loan",
      ["u2000", "u1000"],
      wallet1
    );
    
    expect(loanResult.result).toBeErr();
  });
});