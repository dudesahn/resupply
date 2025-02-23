import { TenderlyHelper } from "script/utils/TenderlyHelper.sol";
import { CreateXHelper } from "script/utils/CreateXHelper.sol";
import { console } from "forge-std/console.sol";
import { ResupplyPairDeployer } from "src/protocol/ResupplyPairDeployer.sol";
import { ResupplyPair } from "src/protocol/ResupplyPair.sol";
import { InterestRateCalculator } from "src/protocol/InterestRateCalculator.sol";
import { BasicVaultOracle } from "src/protocol/BasicVaultOracle.sol";
import { RedemptionHandler } from "src/protocol/RedemptionHandler.sol";
import { LiquidationHandler } from "src/protocol/LiquidationHandler.sol";
import { RewardHandler } from "src/protocol/RewardHandler.sol";
import { FeeDeposit } from "src/protocol/FeeDeposit.sol";
import { FeeDepositController } from "src/protocol/FeeDepositController.sol";
import { SimpleRewardStreamer } from "src/protocol/SimpleRewardStreamer.sol";
import { InsurancePool } from "src/protocol/InsurancePool.sol";
import { SimpleReceiverFactory } from "src/dao/emissions/receivers/SimpleReceiverFactory.sol";
import { SimpleReceiver } from "src/dao/emissions/receivers/SimpleReceiver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IResupplyRegistry } from "src/interfaces/IResupplyRegistry.sol";
import { Stablecoin } from "src/protocol/Stablecoin.sol";
import { ICore } from "src/interfaces/ICore.sol";

contract BaseDeploy is TenderlyHelper, CreateXHelper {
    // Configs: DAO
    uint256 public constant EPOCH_LENGTH = 1 weeks;
    uint256 public constant STAKER_COOLDOWN_EPOCHS = 2;
    uint256 internal constant GOV_TOKEN_INITIAL_SUPPLY = 60_000_000e18;
    address internal constant FRAX_VEST_TARGET = address(0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27);
    address internal constant BURN_ADDRESS = address(0xdead);
    address internal constant PERMA_STAKER1_OWNER = address(1);
    address internal constant PERMA_STAKER2_OWNER = address(2);
    string internal constant PERMA_STAKER1_NAME = "Convex";
    string internal constant PERMA_STAKER2_NAME = "Yearn";
    uint256 internal constant DEBT_RECEIVER_WEIGHT = 4000; // pct of weekly emissions to debt receiver
    uint256 internal constant INSURANCE_EMISSIONS_RECEIVER_WEIGHT = 4000; // pct of weekly emissions to insurance emissions receiver
    uint256 internal constant REUSD_INCENTENIVES_RECEIVER_WEIGHT = 1000; // pct of weekly emissions to reUSD incentives receiver
    uint256 internal constant RSUP_INCENTENIVES_RECEIVER_WEIGHT = 1000; // pct of weekly emissions to burn receiver


    // Configs: Protocol
    uint256 internal constant DEFAULT_MAX_LTV = 95_000; // 95% with 1e5 precision
    uint256 internal constant DEFAULT_LIQ_FEE = 5_000; // 5% with 1e5 precision
    uint256 internal constant DEFAULT_BORROW_LIMIT = 5_000_000 * 1e18;
    uint256 internal constant DEFAULT_MINT_FEE = 0; //1e5 prevision
    uint256 internal constant DEFAULT_PROTOCOL_REDEMPTION_FEE = 1e18 / 2; //half
    uint256 internal constant FEE_SPLIT_IP = 2500; // 25%
    uint256 internal constant FEE_SPLIT_TREASURY = 500; // 5%
    uint256 internal constant FEE_SPLIT_STAKERS = 7000; // 70%

    // Base
    uint88 public randomness; // CREATEX uses the last 88 bits used for randomness
    // address public dev = address(0xc4ad);
    address public dev = address(0xFE11a5009f2121622271e7dd0FD470264e076af6);

    // DAO Contracts
    address public core;
    address public escrow;
    address public staker;
    address public voter;
    address public govToken;
    address public emissionsController;
    address public vestManager;
    address public treasury;
    address public permaStaker1;
    address public permaStaker2;
    address public autoStakeCallback;
    IResupplyRegistry public registry;
    Stablecoin public stablecoin;

    // Protocol Contracts
    BasicVaultOracle public oracle;
    InterestRateCalculator public rateCalculator;
    ResupplyPairDeployer public pairDeployer;
    RedemptionHandler public redemptionHandler;
    LiquidationHandler public liquidationHandler;
    RewardHandler public rewardHandler;
    FeeDeposit public feeDeposit;
    FeeDepositController public feeDepositController;
    SimpleRewardStreamer public ipStableStream;
    SimpleRewardStreamer public ipEmissionStream;
    SimpleRewardStreamer public pairEmissionStream;
    InsurancePool public insurancePool;
    SimpleReceiverFactory public receiverFactory;
    SimpleReceiver public debtReceiver;
    SimpleReceiver public insuranceEmissionsReceiver;
    IERC20 public fraxToken;
    IERC20 public crvusdToken;


    // TODO: Guardiant things
    bytes32 salt; // Use same empty salt for all contracts


    modifier doBroadcast(address _sender) {
        vm.startBroadcast(_sender);
        _;
        vm.stopBroadcast();
    }

    enum DeployType {
        CREATE1,
        CREATE2,
        CREATE3
    }

    function deployContract(
        DeployType _deployType,
        bytes32 _salt,
        bytes memory _bytecode,
        string memory _contractName
    ) internal returns (address) {
        address computedAddress;
        bytes32 computedSalt;
        console.log("Deploying contract:", _contractName, " .... ");
        if (_deployType == DeployType.CREATE1) {
            uint256 nonce = vm.getNonce(address(createXFactory));
            computedAddress = createXFactory.computeCreateAddress(nonce);
            if (address(computedAddress).code.length == 0) {
                computedAddress = createXFactory.deployCreate(_bytecode);
                console.log(string(abi.encodePacked(_contractName, " deployed to:")), address(computedAddress));
            } else {
                console.log(string(abi.encodePacked(_contractName, " already deployed at:")), address(computedAddress));
            }
        } 
        else if (_deployType == DeployType.CREATE2) {
            computedSalt = keccak256(abi.encode(_salt));
            computedAddress = createXFactory.computeCreate2Address(computedSalt, keccak256(_bytecode));
            if (address(computedAddress).code.length == 0) {
                computedAddress = createXFactory.deployCreate2(_salt, _bytecode);
                console.log(string(abi.encodePacked(_contractName, " deployed to:")), address(computedAddress));
            } else {
                console.log(string(abi.encodePacked(_contractName, " already deployed at:")), address(computedAddress));
            }
        } 
        else if (_deployType == DeployType.CREATE3) {
            randomness = uint88(uint256(keccak256(abi.encode(_contractName))));
            // dev address in first 20 bytes, 1 zero byte, then 11 bytes of randomness
            _salt = bytes32(uint256(uint160(dev)) << 96) | bytes32(uint256(0x00)) << 88| bytes32(uint256(randomness));
            console.logBytes32(_salt);
            computedSalt = keccak256(abi.encode(_salt));
            computedAddress = createXFactory.computeCreate3Address(computedSalt);
            if (address(computedAddress).code.length == 0) {
                computedAddress = createXFactory.deployCreate3(_salt, _bytecode);
                console.log(string(abi.encodePacked(_contractName, " deployed to:")), address(computedAddress));
            } else {
                console.log(string(abi.encodePacked(_contractName, " already deployed at:")), address(computedAddress));
            }
        } 
        return computedAddress;
    }

    function _executeCore(address _target, bytes memory _data) internal returns (bytes memory) {
        return addToBatch(
            core,
            abi.encodeWithSelector(
                ICore.execute.selector, address(_target), _data
            )
        );
    }

    function writeAddressToJson(string memory name, address addr) internal {
        // Format: data/chainId_YYYYMMDD.json
        string memory dateStr = vm.toString(block.timestamp / 86400 * 86400); // Round to start of day
        string memory deploymentPath = string.concat(
            vm.projectRoot(), 
            "/data/", 
            vm.toString(block.chainid),
            "_",
            dateStr,
            ".json"
        );
        
        string memory existingContent;
        try vm.readFile(deploymentPath) returns (string memory content) {
            existingContent = content;
        } catch {
            existingContent = "{}";
            vm.writeFile(deploymentPath, existingContent);
        }

        // Parse existing content and add new entry
        string memory newContent;
        if (bytes(existingContent).length <= 2) { // If empty or just "{}"
            newContent = string(abi.encodePacked(
                "{\n",
                '    "', name, '": "', vm.toString(addr), '"',
                "\n}"
            ));
        } else {
            // Remove the closing brace, add comma and new entry
            newContent = string(abi.encodePacked(
                substring(existingContent, 0, bytes(existingContent).length - 2), // Remove final \n}
                ',\n',
                '    "', name, '": "', vm.toString(addr), '"',
                "\n}"
            ));
        }
        
        vm.writeFile(deploymentPath, newContent);
    }

    function substring(string memory str, uint256 startIndex, uint256 endIndex) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
}
