
import { describe, expect, it, beforeEach } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;

const contractName = "Tokenized-Cooperative-Savings";

describe("Tokenized Cooperative Savings - Loan System Tests", () => {
  beforeEach(() => {
    simnet.mineEmptyBlocks(1);
  });

  describe("Member Registration and Contributions", () => {
    it("allows new members to join the cooperative", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "join-cooperative",
        [],
        address1
      );
      expect(result).toBeOk();
    });

    it("allows members to contribute funds", () => {
      simnet.callPublicFn(contractName, "join-cooperative", [], address1);
      
      const { result } = simnet.callPublicFn(
        contractName,
        "contribute",
        ["u5000"],
        address1
      );
      expect(result).toBeOk();
    });

    it("tracks member information correctly", () => {
      simnet.callPublicFn(contractName, "join-cooperative", [], address1);
      simnet.callPublicFn(contractName, "contribute", ["u5000"], address1);
      
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-member-info",
        [`'${address1}`],
        address1
      );
      
      const memberInfo = result.expectTuple();
      expect(memberInfo.balance).toBeUint(5000);
      expect(memberInfo["total-contributed"]).toBeUint(5000);
      expect(memberInfo["active-loan-id"]).toBeNone();
      expect(memberInfo["credit-score"]).toBeUint(110);
    });
  });

  describe("Loan Eligibility and Request System", () => {
    beforeEach(() => {
      simnet.callPublicFn(contractName, "join-cooperative", [], address1);
      simnet.callPublicFn(contractName, "contribute", ["u5000"], address1);
    });

    it("calculates loan eligibility correctly", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "calculate-loan-eligibility",
        [`'${address1}`],
        address1
      );
      
      const eligibility = result.expectTuple();
      expect(eligibility.eligible).toBe(true);
      expect(eligibility["max-amount"]).toBeUint(3750);
      expect(eligibility["current-score"]).toBeUint(110);
    });

    it("rejects loan requests from non-members", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "request-loan",
        ["u1000", "u1000"],
        address2
      );
      expect(result).toBeErr(101); // err-not-member
    });

    it("allows eligible members to request loans", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "request-loan",
        ["u2000", "u1000"],
        address1
      );
      expect(result).toBeOk(1);
    });

    it("rejects loan requests exceeding eligibility limits", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "request-loan",
        ["u4000", "u1000"],
        address1
      );
      expect(result).toBeErr(113); // err-loan-limit-exceeded
    });

    it("prevents members from having multiple active loans", () => {
      simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], address1);
      
      const { result } = simnet.callPublicFn(
        contractName,
        "request-loan",
        ["u1000", "u1000"],
        address1
      );
      expect(result).toBeErr(114); // err-loan-already-active
    });
  });

  describe("Loan Management and Repayment", () => {
    beforeEach(() => {
      simnet.callPublicFn(contractName, "join-cooperative", [], address1);
      simnet.callPublicFn(contractName, "contribute", ["u5000"], address1);
      simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], address1);
    });

    it("creates loan with correct terms", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-loan-info",
        ["u1"],
        address1
      );
      
      expect(result).toBeSome(
        expect.objectContaining({
          borrower: `'${address1}`,
          amount: "u2000",
          "interest-rate": "u10",
          "remaining-balance": "u2200", // 2000 + 200 interest
          "total-interest": "u200",
          status: '"active"',
        })
      );
    });

    it("allows borrowers to make loan payments", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "make-loan-payment",
        ["u1", "u500"],
        address1
      );
      expect(result).toBeOk("u1700"); // remaining balance after payment
    });

    it("updates loan status when fully repaid", () => {
      simnet.callPublicFn(contractName, "make-loan-payment", ["u1", "u2200"], address1);
      
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-loan-info",
        ["u1"],
        address1
      );
      
      const loan = result.expectSome();
      expect(loan["remaining-balance"]).toBe("u0");
      expect(loan.status).toBe('"repaid"');
    });

    it("prevents non-borrowers from making payments", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "make-loan-payment",
        ["u1", "u500"],
        address2
      );
      expect(result).toBeErr(100); // err-owner-only
    });

    it("prevents payments exceeding remaining balance", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "make-loan-payment",
        ["u1", "u3000"],
        address1
      );
      expect(result).toBeErr(115); // err-payment-amount-invalid
    });
  });

  describe("Credit Score and Risk Management", () => {
    beforeEach(() => {
      simnet.callPublicFn(contractName, "join-cooperative", [], address1);
      simnet.callPublicFn(contractName, "contribute", ["u5000"], address1);
    });

    it("increases credit score with contributions", () => {
      simnet.callPublicFn(contractName, "contribute", ["u2500"], address1);
      
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-member-info",
        [`'${address1}`],
        address1
      );
      
      expect(result.expectTuple()["credit-score"]).toBeUint(115); // 110 + (2500/500) = 115
    });

    it("boosts credit score when loan is fully repaid", () => {
      simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], address1);
      simnet.callPublicFn(contractName, "make-loan-payment", ["u1", "u2200"], address1);
      
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-member-info",
        [`'${address1}`],
        address1
      );
      
      const memberInfo = result.expectTuple();
      expect(memberInfo["credit-score"]).toBeUint(130); // 110 + 20 bonus
      expect(memberInfo["active-loan-id"]).toBeNone();
    });

    it("tracks total loans and interest payments", () => {
      simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], address1);
      simnet.callPublicFn(contractName, "make-loan-payment", ["u1", "u1100"], address1);
      
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-member-info",
        [`'${address1}`],
        address1
      );
      
      const memberInfo = result.expectTuple();
      expect(memberInfo["total-loans-taken"]).toBeUint(1);
      expect(memberInfo["total-interest-paid"]).toBeUint(200); // full interest paid
    });
  });

  describe("System Statistics and Read-Only Functions", () => {
    beforeEach(() => {
      simnet.callPublicFn(contractName, "join-cooperative", [], address1);
      simnet.callPublicFn(contractName, "contribute", ["u5000"], address1);
      simnet.callPublicFn(contractName, "join-cooperative", [], address2);
      simnet.callPublicFn(contractName, "contribute", ["u3000"], address2);
    });

    it("tracks total loans outstanding correctly", () => {
      simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], address1);
      simnet.callPublicFn(contractName, "request-loan", ["u1500", "u1000"], address2);
      
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-total-loans-outstanding",
        [],
        address1
      );
      
      expect(result).toBeUint(3850); // 2200 + 1650 (including interest)
    });

    it("returns correct loan count", () => {
      simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], address1);
      simnet.callPublicFn(contractName, "request-loan", ["u1500", "u1000"], address2);
      
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-loan-count",
        [],
        address1
      );
      
      expect(result).toBeUint(2);
    });

    it("prevents loans when insufficient funds available", () => {
      // Create multiple large loans to exhaust available funds
      simnet.callPublicFn(contractName, "request-loan", ["u3000", "u1000"], address1);
      simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], address2);
      
      // Join a new member and try to request a loan
      simnet.callPublicFn(contractName, "join-cooperative", [], address3);
      simnet.callPublicFn(contractName, "contribute", ["u4000"], address3);
      
      const { result } = simnet.callPublicFn(
        contractName,
        "request-loan",
        ["u2000", "u1000"],
        address3
      );
      
      expect(result).toBeErr(102); // err-insufficient-balance
    });
  });

  describe("Edge Cases and Error Handling", () => {
    beforeEach(() => {
      simnet.callPublicFn(contractName, "join-cooperative", [], address1);
    });

    it("prevents loan requests from low-contribution members", () => {
      simnet.callPublicFn(contractName, "contribute", ["u500"], address1); // Below 1000 threshold
      
      const { result } = simnet.callPublicFn(
        contractName,
        "request-loan",
        ["u200", "u1000"],
        address1
      );
      
      expect(result).toBeErr(112); // err-insufficient-credit-score
    });

    it("validates loan duration constraints", () => {
      simnet.callPublicFn(contractName, "contribute", ["u5000"], address1);
      
      // Too short duration
      const result1 = simnet.callPublicFn(
        contractName,
        "request-loan",
        ["u1000", "u100"],
        address1
      );
      expect(result1).toBeErr(115); // err-payment-amount-invalid
      
      // Too long duration
      const result2 = simnet.callPublicFn(
        contractName,
        "request-loan",
        ["u1000", "u5000"],
        address1
      );
      expect(result2).toBeErr(115); // err-payment-amount-invalid
    });

    it("prevents payments on non-existent loans", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "make-loan-payment",
        ["u999", "u500"],
        address1
      );
      
      expect(result).toBeErr(111); // err-loan-not-found
    });

    it("prevents zero-amount payments", () => {
      simnet.callPublicFn(contractName, "contribute", ["u5000"], address1);
      simnet.callPublicFn(contractName, "request-loan", ["u2000", "u1000"], address1);
      
      const { result } = simnet.callPublicFn(
        contractName,
        "make-loan-payment",
        ["u1", "u0"],
        address1
      );
      
      expect(result).toBeErr(115); // err-payment-amount-invalid
    });
  });
});
