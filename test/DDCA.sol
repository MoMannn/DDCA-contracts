// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DDCA} from "../src/DDCA.sol";
import {IEtherexRouter, Route} from "../src/interfaces/IEtherexRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDelegationManager} from "@metamask/delegation-framework/interfaces/IDelegationManager.sol";
import {BaseTest, Implementation, SignatureType} from "../lib/delegation-framework/test/utils/BaseTest.t.sol";
import {ValueLteEnforcer} from "../lib/delegation-framework/src/enforcers/ValueLteEnforcer.sol";
import {ERC20TransferAmountEnforcer} from "../lib/delegation-framework/src/enforcers/ERC20TransferAmountEnforcer.sol";
import {ERC20PeriodTransferEnforcer} from "../lib/delegation-framework/src/enforcers/ERC20PeriodTransferEnforcer.sol";
import {Delegation, Caveat} from "@metamask/delegation-framework/utils/Types.sol";

contract DDCATest is BaseTest {
    DDCA public ddca;

    IEtherexRouter public constant ETHEREX_ROUTER = IEtherexRouter(0x32dB39c56C171b4c96e974dDeDe8E42498929c54);
    IERC20 public constant MUSD = IERC20(0xacA92E438df0B2401fF60dA7E4337B687a2435DA);
    IERC20 public constant USDC = IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff);

    address public constant MUSDC_WHALE = address(0x795fACaa76Aed7C5F44a053155407199F4075139);
    address public constant USDC_WHALE = address(0xB3bfB32977cFd6200AB9537E3703e501d8381c9B);
    uint256 public constant MAINNET_FORK_BLOCK = 25605056;
    uint256 public constant INITIAL_STABLE_BALANCE = 10000000000; // 10k MUSD
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    ValueLteEnforcer public valueLteEnforcer;
    ERC20TransferAmountEnforcer public erc20TransferAmountEnforcer;
    ERC20PeriodTransferEnforcer public erc20PeriodTransferEnforcer;

    function setUp() public override {

        // Set implementation type
        IMPLEMENTATION = Implementation.Hybrid;
        SIGNATURE_TYPE = SignatureType.RawP256;

        super.setUp();

        vm.createSelectFork(vm.envString("LINEA_RPC_URL"), MAINNET_FORK_BLOCK);
        ddca = new DDCA(address(ETHEREX_ROUTER), address(delegationManager));
        ddca.setAllowedFromToken(address(MUSD), true);
        ddca.setAllowedFromToken(address(USDC), true);
        ddca.setAllowedToToken(NATIVE_TOKEN, true);
        ddca.setAllowedToToken(ETHEREX_ROUTER.WETH(), true);

        valueLteEnforcer = new ValueLteEnforcer();
        erc20TransferAmountEnforcer = new ERC20TransferAmountEnforcer();
        erc20PeriodTransferEnforcer = new ERC20PeriodTransferEnforcer();

        console.log("MUSDC balance of whale", MUSD.balanceOf(MUSDC_WHALE));
        console.log("MUSDC balance of alice", MUSD.balanceOf(users.alice.addr));
        vm.prank(MUSDC_WHALE);
        MUSD.transfer(users.alice.addr, INITIAL_STABLE_BALANCE); // 10k MUSD   
        vm.prank(MUSDC_WHALE);
        MUSD.transfer(address(users.alice.deleGator), INITIAL_STABLE_BALANCE); // 10k MUSD   
        vm.prank(USDC_WHALE);
        USDC.transfer(users.alice.addr, INITIAL_STABLE_BALANCE); // 10k USDC
        vm.prank(USDC_WHALE);
        USDC.transfer(address(users.alice.deleGator), INITIAL_STABLE_BALANCE); // 10k USDC

        vm.deal(address(users.alice.addr), 1 ether);
        vm.deal(address(users.alice.deleGator), 1 ether);
    }

    function test_swapMUSDToETH() public {
        uint256 amountIn = 1000000000; // 1k MUSD

        console.log("alice MUSD before swap", MUSD.balanceOf(users.alice.addr));
        console.log("alice ETH before swap", users.alice.addr.balance);

        vm.startPrank(users.alice.addr);
        MUSD.approve(address(ETHEREX_ROUTER), amountIn);
        ETHEREX_ROUTER.swapExactTokensForETH(
            amountIn,
            0,
            _buildRoute(address(MUSD), NATIVE_TOKEN),
            users.alice.addr,
            block.timestamp + 1000
        );
        vm.stopPrank();
        console.log("alice MUSD after swap", MUSD.balanceOf(users.alice.addr));
        console.log("alice ETH after swap", users.alice.addr.balance);
    }

    function test_swapByTransferDelegationUSDCToETH() public {
        uint256 amountIn = 1000000000; // 1k USDC
        console.log("alice USDC before swap", USDC.balanceOf(address(users.alice.deleGator)));
        console.log("alice ETH before swap", address(users.alice.deleGator).balance);

        Delegation memory transferDelegation =
            _createTransferDelegation(address(ddca), address(USDC), amountIn);

        vm.startPrank(users.alice.addr);

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = transferDelegation;

        ddca.swapByDelegation(delegations_, _buildRoute(address(USDC), NATIVE_TOKEN), amountIn, true);

        vm.stopPrank();

        console.log("alice USDC after swap by delegation", USDC.balanceOf(address(users.alice.deleGator)));
        console.log("alice ETH after swap by delegation", address(users.alice.deleGator).balance);
    }

    function test_swapByPeriodDelegationUSDCToETH() public {
        uint256 amountIn = 1000000000; // 1k USDC

        uint256 initialUSDCBalance = USDC.balanceOf(address(users.alice.deleGator));
        console.log("alice USDC before swap", initialUSDCBalance);
        console.log("alice ETH before swap", address(users.alice.deleGator).balance);

        Route[] memory routes_ = _buildRoute(address(USDC), NATIVE_TOKEN);
        Delegation memory transferDelegation =
            _createPeriodDelegation(address(ddca), address(USDC), amountIn, 7 days, block.timestamp + 1 days);

        vm.startPrank(users.alice.addr);

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = transferDelegation;

        vm.expectRevert();
        ddca.swapByDelegation(delegations_, routes_, amountIn, true);

        vm.warp(block.timestamp + 1 days);
        ddca.swapByDelegation(delegations_, routes_, amountIn, true);
        console.log("alice USDC after swap by delegation", USDC.balanceOf(address(users.alice.deleGator)));
        initialUSDCBalance = initialUSDCBalance - amountIn;
        assertEq(USDC.balanceOf(address(users.alice.deleGator)), initialUSDCBalance);

        vm.expectRevert();
        ddca.swapByDelegation(delegations_, routes_, amountIn, true);

        vm.warp(block.timestamp + 7 days);

        ddca.swapByDelegation(delegations_, routes_, amountIn, true);

        vm.stopPrank();

        assertEq(USDC.balanceOf(address(users.alice.deleGator)), initialUSDCBalance - amountIn);

        console.log("alice USDC after swap by delegation", USDC.balanceOf(address(users.alice.deleGator)));
        console.log("alice ETH after swap by delegation", address(users.alice.deleGator).balance);
    }

    function _buildRoute(address _tokenFrom, address _tokenTo) private view returns (Route[] memory routes_) {
        // Handle ETH to token conversion for quote (convert NATIVE_TOKEN to WETH)
        address tokenFromForQuote_ = _tokenFrom == NATIVE_TOKEN ? ETHEREX_ROUTER.WETH() : _tokenFrom;
        address tokenToForQuote_ = _tokenTo == NATIVE_TOKEN ? ETHEREX_ROUTER.WETH() : _tokenTo;
        
        // Special handling for MUSD: always route through USDC
        if (tokenFromForQuote_ == address(MUSD)) {
            // If destination is USDC, just one hop
            if (tokenToForQuote_ == address(USDC)) {
                routes_ = new Route[](1);
                routes_[0] = Route({
                    from: address(MUSD),
                    to: address(USDC),
                    stable: true  // MUSD -> USDC is stable
                });
            } else {
                // Two hops: MUSD -> USDC -> tokenTo
                routes_ = new Route[](2);
                routes_[0] = Route({
                    from: address(MUSD),
                    to: address(USDC),
                    stable: true  // MUSD -> USDC is stable
                });
                routes_[1] = Route({
                    from: address(USDC),
                    to: tokenToForQuote_,
                    stable: false  // USDC -> tokenTo is not stable
                });
            }
        } else {
            // Standard single route for non-MUSD pairs
            routes_ = new Route[](1);
            routes_[0] = Route({
                from: tokenFromForQuote_,
                to: tokenToForQuote_,
                stable: false
            });
        }
    }

    /// @notice Creates a transfer delegation with all security restrictions
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

        // Restrict to approve function
        caveats_[0] =
            Caveat({ args: hex"", enforcer: address(erc20TransferAmountEnforcer), terms: abi.encodePacked(_token, _amount) });

        // Set value limit to 0
        caveats_[1] = Caveat({ args: hex"", enforcer: address(valueLteEnforcer), terms: abi.encode(0) });

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

     /// @notice Creates a transfer delegation with all security restrictions
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

        // Restrict to approve function
        caveats_[0] =
            Caveat({ args: hex"", enforcer: address(erc20PeriodTransferEnforcer), terms: abi.encodePacked(_token, _amount, _duration, _startTime) });

        // Set value limit to 0
        caveats_[1] = Caveat({ args: hex"", enforcer: address(valueLteEnforcer), terms: abi.encode(0) });

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

    /// @notice Test that flat fee (0.1 USDC) is distributed correctly for small swaps
    /// @dev When swap amount is small, minimumFee (0.1 USDC) should be taken
    function test_FeeDistribution_FlatFee_0_1_USDC() public {
        uint256 amountIn = 1000000; // 1 USDC (small amount to trigger minimum fee)
        
        address owner = ddca.owner();
        uint256 ownerUSDCBefore = USDC.balanceOf(owner);
        uint256 deleGatorUSDCBefore = USDC.balanceOf(address(users.alice.deleGator));

        console.log("owner USDC before swap", ownerUSDCBefore);
        console.log("delegator USDC before swap", deleGatorUSDCBefore);

        Delegation memory transferDelegation =
            _createTransferDelegation(address(ddca), address(USDC), amountIn);

        vm.startPrank(users.alice.addr);

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = transferDelegation;

        ddca.swapByDelegation(delegations_, _buildRoute(address(USDC), NATIVE_TOKEN), amountIn, true);

        vm.stopPrank();

        uint256 ownerUSDCAfter = USDC.balanceOf(owner);
        uint256 expectedFee = ddca.minimumFee(); // Should be 100000 (0.1 USDC)
        
        // Calculate percentage fee to verify it's less than minimum
        uint256 percentageFee = (amountIn * ddca.feePercentageBps()) / 10000; // 1 USDC * 0.1% = 0.001 USDC
        
        console.log("percentage fee would be", percentageFee);
        console.log("minimum fee", expectedFee);
        console.log("owner USDC after swap", ownerUSDCAfter);
        console.log("fee collected", ownerUSDCAfter - ownerUSDCBefore);

        // Assert that the flat fee was taken (not percentage)
        assertEq(ownerUSDCAfter - ownerUSDCBefore, expectedFee, "Flat fee should be taken for small amounts");
        assertLt(percentageFee, expectedFee, "Percentage fee should be less than minimum fee");
    }

    /// @notice Test that percentage-based fee is distributed correctly for large swaps
    /// @dev When swap amount is large, percentage fee should exceed minimumFee
    function test_FeeDistribution_PercentageBased() public {
        uint256 amountIn = 5000000000; // 5000 USDC (large amount to trigger percentage fee)
        
        address owner = ddca.owner();
        uint256 ownerUSDCBefore = USDC.balanceOf(owner);
        uint256 deleGatorUSDCBefore = USDC.balanceOf(address(users.alice.deleGator));

        console.log("owner USDC before swap", ownerUSDCBefore);
        console.log("delegator USDC before swap", deleGatorUSDCBefore);

        Delegation memory transferDelegation =
            _createTransferDelegation(address(ddca), address(USDC), amountIn);

        vm.startPrank(users.alice.addr);

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = transferDelegation;

        ddca.swapByDelegation(delegations_, _buildRoute(address(USDC), NATIVE_TOKEN), amountIn, true);

        vm.stopPrank();

        uint256 ownerUSDCAfter = USDC.balanceOf(owner);
        
        // Calculate expected fees
        uint256 percentageFee = (amountIn * ddca.feePercentageBps()) / 10000; // 5000 USDC * 0.1% = 5 USDC
        uint256 minimumFee = ddca.minimumFee();
        
        console.log("percentage fee", percentageFee);
        console.log("minimum fee", minimumFee);
        console.log("owner USDC after swap", ownerUSDCAfter);
        console.log("fee collected", ownerUSDCAfter - ownerUSDCBefore);

        // Assert that the percentage fee was taken (not flat)
        assertEq(ownerUSDCAfter - ownerUSDCBefore, percentageFee, "Percentage fee should be taken for large amounts");
        assertGt(percentageFee, minimumFee, "Percentage fee should be greater than minimum fee");
    }

}
