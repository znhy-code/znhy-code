pragma solidity ^0.5.0;

/**
 * @title DB
 * @dev This Provide database support services
 */
contract DB {

	struct UserInfo {
		uint id;
        address code;
		address rCode;
        uint status;
	}

    mapping(address => address) addressMapping;//inviteCode address Mapping
    mapping(address => UserInfo) userInfoMapping;//address UserInfo Mapping


    /**
     * @dev get the user address of the corresponding user invite code
     * Authorization Required
     * @param code user invite Code
     * @return address
     */
    function _getCodeMapping(address code)
        internal
        view
        returns (address)
    {
        // addr = addressMapping[code];
		return addressMapping[code];
	}

    /**
     * @dev get the user address of the corresponding User info
     * Authorization Required or addr is owner
     * @param addr user address
     * @return info[id,status],code,rCode
     */
    function _getUserInfo(address addr)
        internal
        view
        returns (uint[2] memory info, address code, address rCode)
    {
		UserInfo memory userInfo = userInfoMapping[addr];
		info[0] = userInfo.id;
		info[1] = userInfo.status;

		return (info, userInfo.code, userInfo.rCode);
	}
}

/**
 * @title Utillibrary
 * @dev This integrates the basic functions.
 */
contract Utillibrary {
    //base param setting
    uint internal USDTWei = 10 ** 6;

    /**
     * @dev modifier to scope access to a Contract (uses tx.origin and msg.sender)
     */
	modifier isHuman() {
		require(msg.sender == tx.origin, "humans only");
		_;
	}

    /**
     * @dev check User ID
     * @param uid user ID
     */
    function checkUserID(uint uid)
        internal
        pure
    {
        require(uid != 0, "user not exist");
	}

    /**
     * @dev get scale for the level (*scale/100)
     * @param level level
     * @return scale
     */
	function getScaleByLevel(uint level)
        internal
        pure
        returns (uint)
    {
		if (level == 1) {
			return 5;
		}
		if (level == 2) {
			return 10;
		}
		if (level == 3) {
			return 15;
		}
		return 0;
	}
}


contract znhyContract is DB, Utillibrary {
    //struct
	struct User {
		uint id;
		address userAddress;
		uint level;//user level
        uint investAmount;//add up invest Amount
        uint investAmountOut;//add up invest Amount Out
        uint investIndex;//invest Index
        uint maxInvestIndex;//Max invest Index
        mapping(uint => InvestData) investData;
        mapping(uint => uint) rewardIndex;
        mapping(uint => mapping(uint => AwardData)) rewardData;
        uint bonusStaticAmount;//add up static bonus amonut (static bonus)
		uint bonusDynamicAmonut;//add up dynamic bonus amonut (dynamic bonus)
        uint takeBonusWallet;//takeBonus Wallet
        uint addupTakeBonus;//add up takeBonus
	}
    struct InvestData {
        uint money;//invest amount
        uint lastRwTime;//last settlement time
        uint adduoStaticBonus;//add up settlement static bonus amonut
        uint adduoDynamicBonus;//add up settlement dynamic bonus amonut
        uint status;//invest status, 0:normal,1:out
	}
	struct AwardData {
        uint time;//settlement bonus time
        uint amount;//bonus of reward amount
	}

    //address User Mapping
	mapping(address => User) userMapping;


    /**
     * @dev the content of contract is Beginning
     */
	constructor (
    )
        public
    {

	}


    /**
     * @dev settlement
     * @param _type settlement type (0:Static,1:Node,2:DailyDividend,3:ServiceFees,4:SameLevel)
     */
    function settlement(uint _type)
        public
        isHuman()
    {
		User storage user = userMapping[msg.sender];
        checkUserID(user.id);

        //reacquire rCode
        address rCode;
        uint[2] memory user_data;
        (user_data, , rCode) = _getUserInfo(msg.sender);

        if (_type == 0) {

            //-----------Static Start
            uint settlementCountTotal = 0;
            for (uint i = 0; i < user.investIndex; i++) {
                InvestData storage investData = user.investData[i];
                uint settlementNumber_base = (now - investData.lastRwTime) / 1 days;
                if (investData.status == 0 && settlementNumber_base > 0) {
                    //Handling fee safety
                    if (settlementCountTotal >= 10) {
                        break;
                    }
                    settlementCountTotal ++;

                    uint moneyBonus_base = investData.money * 5 / 1000;
                    uint settlementNumber = settlementNumber_base;
                    uint settlementMaxMoney = 0;
                    if(investData.money * 3 >= investData.adduoStaticBonus + investData.adduoDynamicBonus) {
                       settlementMaxMoney = investData.money * 3 - (investData.adduoStaticBonus + investData.adduoDynamicBonus);
                    }
                    uint moneyBonus = 0;
                    if (moneyBonus_base * settlementNumber > settlementMaxMoney) {
                        settlementNumber = settlementMaxMoney / moneyBonus_base;
                        if (moneyBonus_base * settlementNumber < settlementMaxMoney) {
                            settlementNumber ++;
                        }
                        if (settlementNumber > settlementNumber_base) {
                            settlementNumber = settlementNumber_base;
                        }
                        // moneyBonus = moneyBonus_base * settlementNumber;
                        moneyBonus = settlementMaxMoney;
                    } else {
                        moneyBonus = moneyBonus_base * settlementNumber;
                    }

                    user.takeBonusWallet += moneyBonus;
                    user.bonusStaticAmount += moneyBonus;

                    investData.adduoStaticBonus += moneyBonus;
                    investData.lastRwTime += settlementNumber * 1 days;
                    //check out
                    if (investData.adduoStaticBonus + investData.adduoDynamicBonus >= investData.money * 3) {
                        investData.status = 1;
                        user.investAmountOut += investData.money;
						user.maxInvestIndex = getMaxInvestData(msg.sender);
                    }
                }
            }
            //-----------Static End
        } else if (_type == 3) {

            //-----------ServiceFees
            AwardData storage awData = user.rewardData[_type][user.rewardIndex[_type]];

            require(awData.amount > 0, "amount is zero");

            user.rewardIndex[_type] ++;
            awData.time = now;
            user.takeBonusWallet += awData.amount;
            //-----------ServiceFees
        }
	}

    /**
     * @dev get Max Invest Data
     * @param addr user address
     */
	function getMaxInvestData(address addr)
        private
        view
        returns (uint maxInvestDataIndex)
    {
        uint maxInvest = 0;
        User storage user = userMapping[addr];
        for (uint i = 0; i < user.investIndex; i++) {
            InvestData memory investData = user.investData[i];
            if (investData.status == 0 && maxInvest <= investData.money) {
                maxInvest = investData.money;
                maxInvestDataIndex = i;
            }
        }
        return maxInvestDataIndex;
	}

    /**
     * @dev Update and Check Invest Out (dynamic Bonus)
     * @param addr user address
     * @param dynamicBonusAmount dynamic Bonus Amount
     * @return bonus amount
     */
	function update_DynamicBonusCheckInvestOut(address addr, uint dynamicBonusAmount)
        private
        returns (uint bonusAmount)
    {
        User storage user = userMapping[addr];

        InvestData storage investData = user.investData[user.maxInvestIndex];

        if (investData.status == 0) {
            if (investData.adduoStaticBonus + investData.adduoDynamicBonus + dynamicBonusAmount >= investData.money * 3) {
                investData.status = 1;
                user.investAmountOut += investData.money;
                user.maxInvestIndex = getMaxInvestData(addr);

                bonusAmount = investData.money * 3 - (investData.adduoStaticBonus + investData.adduoDynamicBonus);
                bonusAmount += update_DynamicBonusCheckInvestOut(addr, dynamicBonusAmount);
            } else {
                bonusAmount = dynamicBonusAmount;
            }
        }

        user.bonusDynamicAmonut += bonusAmount;
        investData.adduoDynamicBonus += bonusAmount;
        return bonusAmount;
	}

    /**
     * @dev Calculate the bonus (All) and update Parent User
     * @param rCode user recommend code
     * @param money invest money
     */
	function countBonus_All(address rCode, uint money)
        private
    {
        uint maxLevel_ServiceFees = 0;
        uint[] memory level_baseMoney_ServiceFees = new uint[](4);

		address tmpReferrerCode = rCode;
        uint[2] memory user_data;
        address tmpUser_rCode;
        uint user_status = 0;

        uint moneyBonus = 0;

		for (uint i = 1; i <= 21; i++) {
			if (tmpReferrerCode == address(0)) {
				break;
			}

            User storage user = userMapping[_getCodeMapping(tmpReferrerCode)];

            //last rRcode and currUserInfo
            (user_data, , tmpUser_rCode) = _getUserInfo(user.userAddress);
            user_status = user_data[1];

            //-----------ServiceFees Start
            if (user.level >= 1) {
                if (user.level > maxLevel_ServiceFees) {
                    moneyBonus = money * (getScaleByLevel(user.level) - getScaleByLevel(maxLevel_ServiceFees)) / 100;

                    if(user.investAmount > user.investAmountOut && user_status == 0) {
                        AwardData storage awData_ServiceFees = user.rewardData[3][user.rewardIndex[3]];
                        //check out
                        awData_ServiceFees.amount += update_DynamicBonusCheckInvestOut(user.userAddress, moneyBonus);
                    }

                    level_baseMoney_ServiceFees[user.level] = moneyBonus;
                    maxLevel_ServiceFees = user.level;
                }
            }
            //-----------ServiceFees End

            tmpReferrerCode = tmpUser_rCode;
		}
	}
}