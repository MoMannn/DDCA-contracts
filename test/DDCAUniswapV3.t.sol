// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDelegationManager} from "@metamask/delegation-framework/interfaces/IDelegationManager.sol";
import {BaseTest, Implementation, SignatureType} from "../lib/delegation-framework/test/utils/BaseTest.t.sol";
import {ValueLteEnforcer} from "../lib/delegation-framework/src/enforcers/ValueLteEnforcer.sol";
import {ERC20TransferAmountEnforcer} from "../lib/delegation-framework/src/enforcers/ERC20TransferAmountEnforcer.sol";
import {ERC20PeriodTransferEnforcer} from "../lib/delegation-framework/src/enforcers/ERC20PeriodTransferEnforcer.sol";
import {Delegation, Caveat} from "@metamask/delegation-framework/utils/Types.sol";
// Import contract
import {DDCAUniswapV3} from "../src/DDCAUniswapV3.sol";

contract DDCAUniswapV3Test is BaseTest {
    DDCAUniswapV3 public ddca;

    // Uniswap V3 SwapRouter02 and QuoterV2 addresses on Ethereum Mainnet
    // https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
    address public constant SWAP_ROUTER = address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address public constant QUOTER = address(0x61fFE014bA17989E743c5F6cB21bF9697530B21e); // QuoterV2 

    // Token addresses
    IERC20 public constant MUSD = IERC20(0xacA92E438df0B2401fF60dA7E4337B687a2435DA);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    
    // Pool fee tiers in Uniswap V3
    uint24 public constant FEE_LOW = 500;      // 0.05%
    uint24 public constant FEE_MEDIUM = 3000;  // 0.3%
    uint24 public constant FEE_HIGH = 10000;   // 1%
    
    // Whale addresses for token distribution
    address public constant MUSD_WHALE = address(0x992eF7fF7D9c93b9E6CA4f95dB936A389B677422);
    address public constant USDC_WHALE = address(0x28db54CF01483176D462558082e97Dc4e483aA07);
    uint256 public constant FORK_BLOCK = 23818728;
    uint256 public constant INITIAL_BALANCE = 10000 * 1e6; // 10k tokens (6 decimals for USDC/MUSD)

    ValueLteEnforcer public valueLteEnforcer;
    ERC20TransferAmountEnforcer public erc20TransferAmountEnforcer;
    ERC20PeriodTransferEnforcer public erc20PeriodTransferEnforcer;

    function setUp() public override {
        // Set implementation type
        IMPLEMENTATION = Implementation.Hybrid;
        SIGNATURE_TYPE = SignatureType.RawP256;

        super.setUp();

        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK);
        
        ddca = new DDCAUniswapV3(
            SWAP_ROUTER,
            QUOTER,
            address(delegationManager)
        );
        
        // Allow tokens as source
        ddca.setAllowedFromToken(address(USDC), true);
        ddca.setAllowedFromToken(address(MUSD), true);
        
        // Allow WETH as destination
        ddca.setAllowedToToken(WETH, true);

        valueLteEnforcer = new ValueLteEnforcer();
        erc20TransferAmountEnforcer = new ERC20TransferAmountEnforcer();
        erc20PeriodTransferEnforcer = new ERC20PeriodTransferEnforcer();

        // Setup token balances for testing
        vm.prank(USDC_WHALE);
        USDC.transfer(users.alice.addr, INITIAL_BALANCE);
        vm.prank(USDC_WHALE);
        USDC.transfer(address(users.alice.deleGator), INITIAL_BALANCE);
        
        vm.prank(MUSD_WHALE);
        MUSD.transfer(users.alice.addr, INITIAL_BALANCE);
        vm.prank(MUSD_WHALE);
        MUSD.transfer(address(users.alice.deleGator), INITIAL_BALANCE);
        
        // Give delegator some ETH for gas
        vm.deal(address(users.alice.deleGator), 10 ether);
    }

    /// @notice Creates a transfer delegation with security restrictions
    /// @param _delegate Address that can execute the delegation
    /// @param _token Address to approve
    /// @param _amount Amount to approve
    /// @return Signed delegation ready for execution
    function _createTransferDelegation(
        address _delegate,
        address _token,
        uint256 _amount
    )
        internal
        view
        returns (Delegation memory)
    {
        Caveat[] memory caveats_ = new Caveat[](2);

        // Restrict to transfer function with specific amount
        caveats_[0] = Caveat({
            args: hex"",
            enforcer: address(erc20TransferAmountEnforcer),
            terms: abi.encodePacked(_token, _amount)
        });

        // Set value limit to 0
        caveats_[1] = Caveat({
            args: hex"",
            enforcer: address(valueLteEnforcer),
            terms: abi.encode(0)
        });

        Delegation memory delegation_ = Delegation({
            delegate: _delegate,
            delegator: address(users.alice.deleGator),
            authority: ROOT_AUTHORITY,
            caveats: caveats_,
            salt: 0,
            signature: hex""
        });

        return signDelegation(users.alice, delegation_);
    }

    /// @notice Creates a period-based delegation with time restrictions
    /// @param _delegate Address that can execute the delegation
    /// @param _token Address to approve
    /// @param _amount Amount to approve
    /// @param _duration Duration of the period
    /// @param _startTime Start time of the period
    /// @return Signed delegation ready for execution
    function _createPeriodDelegation(
        address _delegate,
        address _token,
        uint256 _amount,
        uint256 _duration,
        uint256 _startTime
    )
        internal
        view
        returns (Delegation memory)
    {
        Caveat[] memory caveats_ = new Caveat[](2);

        // Restrict to periodic transfers
        caveats_[0] = Caveat({
            args: hex"",
            enforcer: address(erc20PeriodTransferEnforcer),
            terms: abi.encodePacked(_token, _amount, _duration, _startTime)
        });

        // Set value limit to 0
        caveats_[1] = Caveat({
            args: hex"",
            enforcer: address(valueLteEnforcer),
            terms: abi.encode(0)
        });

        Delegation memory delegation_ = Delegation({
            delegate: _delegate,
            delegator: address(users.alice.deleGator),
            authority: ROOT_AUTHORITY,
            caveats: caveats_,
            salt: 0,
            signature: hex""
        });

        return signDelegation(users.alice, delegation_);
    }

    /// @notice Test USDC to WETH swap with delegation
    /// @dev Swaps USDC for WETH using Uniswap V3 on mainnet fork
    function test_swapUSDCtoWETH() public {
        uint256 amountIn = 1000 * 1e6; // 1000 USDC

        // Record balances before swap
        uint256 usdcBefore = USDC.balanceOf(address(users.alice.deleGator));
        uint256 wethBefore = IERC20(WETH).balanceOf(address(users.alice.deleGator));
        
        console.log("USDC balance before:", usdcBefore);
        console.log("WETH balance before:", wethBefore);

        // Create delegation to transfer USDC
        Delegation memory transferDelegation = _createTransferDelegation(
            address(ddca),
            address(USDC),
            amountIn
        );

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = transferDelegation;

        // Execute swap: USDC -> WETH with 0.3% fee
        ddca.swapByDelegation(
            delegations_,
            address(USDC),  // tokenIn
            WETH,           // tokenOut
            FEE_MEDIUM,     // 0.3% fee tier
            amountIn
        );

        // Check balances after swap
        uint256 usdcAfter = USDC.balanceOf(address(users.alice.deleGator));
        uint256 wethAfter = IERC20(WETH).balanceOf(address(users.alice.deleGator));
        
        console.log("USDC balance after:", usdcAfter);
        console.log("WETH balance after:", wethAfter);
        console.log("WETH received:", wethAfter - wethBefore);

        // Verify USDC was spent
        assertLt(usdcAfter, usdcBefore, "USDC should decrease");
        
        // Verify WETH was received
        assertGt(wethAfter, wethBefore, "Should receive WETH");
    }

    /// @notice Test fee distribution for small amounts (flat fee)
    function test_FeeDistribution_FlatFee() public {
        uint256 amountIn = 10 * 1e6; // 10 USDC (small amount to trigger flat fee)
        
        address owner = ddca.owner();
        uint256 ownerUSDCBefore = USDC.balanceOf(owner);

        Delegation memory transferDelegation = _createTransferDelegation(
            address(ddca),
            address(USDC),
            amountIn
        );

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = transferDelegation;

        ddca.swapByDelegation(
            delegations_,
            address(USDC),  // tokenIn
            WETH,           // tokenOut
            FEE_MEDIUM,     // 0.3% fee tier
            amountIn
        );

        // Check fee collected
        uint256 ownerUSDCAfter = USDC.balanceOf(owner);
        uint256 feeCollected = ownerUSDCAfter - ownerUSDCBefore;
        
        console.log("Fee collected:", feeCollected);
        console.log("Minimum fee:", ddca.minimumFee());
        
        // For small amounts, should collect minimum fee (1 USDC = 1e6)
        uint256 expectedFee = ddca.minimumFee();
        uint256 percentageFee = (amountIn * ddca.feePercentageBps()) / 10000;
        
        assertEq(feeCollected, expectedFee, "Should collect minimum flat fee");
        assertLt(percentageFee, expectedFee, "Percentage fee should be less than minimum fee");
    }

    /// @notice Test fee distribution for large amounts (percentage fee)
    function test_FeeDistribution_PercentageBased() public {
        uint256 amountIn = 5000 * 1e6; // 5000 USDC (large amount)
        
        address owner = ddca.owner();
        uint256 ownerUSDCBefore = USDC.balanceOf(owner);

        Delegation memory transferDelegation = _createTransferDelegation(
            address(ddca),
            address(USDC),
            amountIn
        );

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = transferDelegation;

        ddca.swapByDelegation(
            delegations_,
            address(USDC),  // tokenIn
            WETH,           // tokenOut
            FEE_MEDIUM,     // 0.3% fee tier
            amountIn
        );

        // Check fee collected
        uint256 ownerUSDCAfter = USDC.balanceOf(owner);
        uint256 feeCollected = ownerUSDCAfter - ownerUSDCBefore;
        
        console.log("Fee collected:", feeCollected);
        console.log("Minimum fee:", ddca.minimumFee());
        
        // For large amounts, should collect percentage fee (0.1% = 5 USDC)
        uint256 percentageFee = (amountIn * ddca.feePercentageBps()) / 10000;
        uint256 minimumFee = ddca.minimumFee();
        
        assertEq(feeCollected, percentageFee, "Should collect percentage fee");
        assertGt(percentageFee, minimumFee, "Percentage fee should be greater than minimum fee");
    }

    /// @notice Test period-based delegation for DCA
    function test_swapByPeriodDelegation() public {
        uint256 amountIn = 100 * 1e6; // 100 USDC per period

        // Create period delegation: 100 USDC every 7 days, starting in 1 day
        Delegation memory periodDelegation = _createPeriodDelegation(
            address(ddca),
            address(USDC),
            amountIn,
            7 days,
            block.timestamp + 1 days
        );

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = periodDelegation;

        // Should revert before start time
        vm.expectRevert();
        ddca.swapByDelegation(
            delegations_,
            address(USDC),
            WETH,
            FEE_MEDIUM,
            amountIn
        );

        // Fast forward to start time
        vm.warp(block.timestamp + 1 days);
        
        uint256 usdcBefore = USDC.balanceOf(address(users.alice.deleGator));
        
        // First swap should succeed
        ddca.swapByDelegation(
            delegations_,
            address(USDC),
            WETH,
            FEE_MEDIUM,
            amountIn
        );
        
        uint256 usdcAfter = USDC.balanceOf(address(users.alice.deleGator));
        assertEq(usdcBefore - usdcAfter, amountIn, "Should swap exactly 100 USDC");

        // Should revert if trying again before period expires
        vm.expectRevert();
        ddca.swapByDelegation(
            delegations_,
            address(USDC),
            WETH,
            FEE_MEDIUM,
            amountIn
        );

        // Fast forward 7 days
        vm.warp(block.timestamp + 7 days);
        
        // Second swap should succeed
        ddca.swapByDelegation(
            delegations_,
            address(USDC),
            WETH,
            FEE_MEDIUM,
            amountIn
        );
    }

    /// @notice Test getting a quote before swapping
    function test_getQuote() public {
        uint256 amountIn = 1000 * 1e6; // 1000 USDC

        // Get quote for USDC -> WETH
        (uint256 expectedOut, uint256 minOut) = ddca.getQuote(
            address(USDC),
            WETH,
            FEE_MEDIUM,
            amountIn
        );
        
        console.log("Input USDC:", amountIn);
        console.log("Expected WETH output:", expectedOut);
        console.log("Minimum WETH output (after slippage):", minOut);
        
        // Verify quote is reasonable
        assertGt(expectedOut, 0, "Expected output should be positive");
        assertLt(minOut, expectedOut, "Min output should be less than expected");
        
        // Verify slippage calculation (allow 1 wei rounding error)
        uint256 expectedSlippage = (expectedOut * ddca.slippageBps()) / 10000;
        assertApproxEqAbs(expectedOut - minOut, expectedSlippage, 1, "Slippage should match configured tolerance");
    }

    /// @notice Test admin functions
    function test_AdminFunctions() public {
        // Test setting allowed tokens
        ddca.setAllowedFromToken(address(0x7), true);
        assertTrue(ddca.allowedFromTokens(address(0x7)));

        ddca.setAllowedToToken(address(0x8), true);
        assertTrue(ddca.allowedToTokens(address(0x8)));

        // Test fee configuration
        ddca.setMinimumFee(2 * 1e6); // 2 USDC
        assertEq(ddca.minimumFee(), 2 * 1e6);

        ddca.setFeePercentageBps(20); // 0.2%
        assertEq(ddca.feePercentageBps(), 20);

        ddca.setSlippageBps(100); // 1%
        assertEq(ddca.slippageBps(), 100);
    }
}

