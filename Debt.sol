pragma solidity>=0.4.24 <0.6.11;
pragma experimental ABIEncoderV2;

import "./Table.sol";

contract Debt
{
    function toString(address account) public pure returns(string memory) {
        return toString(abi.encodePacked(account));
    }

    function toString(uint256 value) public pure returns(string memory) {
        return toString(abi.encodePacked(value));
    }

    function toString(bytes32 value) public pure returns(string memory) {
        return toString(abi.encodePacked(value));
    }

    function toString(bytes memory data) public pure returns(string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    uint OTHER = 0;
    uint BANK = 1;
    struct Company
    {
        uint cType;
    }

    mapping(address => Company) public companies;

    constructor() public
    {
        // 构造函数中创建debt表
        createTable();
    }

    /*
    描述 : 公司注册
    参数 ：
            cType: 公司类型
    返回值：
            无
    */

    function register(uint cType) public
    {
        companies[msg.sender].cType = cType;
    }

    int DB_ERR = -4;
    int OVERFLOW = -3;
    int NOT_BANK = -2;
    int NOT_EXIST = -1;
    int SUCC = 0;
    string id = "0";
    function createTable() private
    {
        TableFactory tf = TableFactory(0x1001);
        // 应收账款表, key : account, field : asset_value
        // |主码   |债权人     |债务人      |还款日期     |挂起(主码)|金额    |
        // |------|-----------|-----------|-------------|---------|-------|
        // |id    |creditor   |debtor     |ddl          |pending  |value  |
        // |string|address    |address    |uint256      |address  |uint256|
        //
        // 创建表
        tf.createTable("debt", "id", "creditor,debtor,ddl,pending,value");
    }

    function openTable() private returns(Table)
    {
        TableFactory tf = TableFactory(0x1001);
        Table table = tf.openTable("debt");
        return table;
    }

    struct DEBT
    {
        address creditor;
        address debtor;
        uint256 ddl;
        address pending;
        uint256 value;
    }

    /*
    描述 : 查询相关debt
    参数 ：
            无

    返回值：
            参数一： 成功返回0, 账户不存在返回-1
            参数二： 第一个参数为0时有效，debt_list
    */
    function select() public returns (int, DEBT [] memory)
    {
        // 打开表
        Table table = openTable();
        // 查询
        Condition condition;

        condition = table.newCondition();
        condition.EQ("creditor", toString(msg.sender));
        Entries entries0 = table.select(id, condition);

        condition = table.newCondition();
        condition.EQ("debtor", toString(msg.sender));
        Entries entries1 = table.select(id, condition);

        if (companies[msg.sender].cType == BANK)
        {
            condition = table.newCondition();
            condition.EQ("pending", toString(msg.sender));
            Entries entries2 = table.select(id, condition);
        }

        int256 total_size = entries0.size() + entries1.size();
        if (companies[msg.sender].cType == BANK)
        {
            total_size += entries2.size();
        }

        DEBT[] memory debt_list = new DEBT[](uint256(total_size));
        if (total_size == 0)
        {
            return (NOT_EXIST, debt_list);
        }
        uint256 i = 0;
        int256 j;
        Entry entry;

        for (j = 0; j < entries0.size(); j++)
        {
            entry = entries0.get(j);
            debt_list[i].creditor = entry.getAddress("creditor");
            debt_list[i].debtor = entry.getAddress("debtor");
            debt_list[i].ddl = entry.getUInt("ddl");
            debt_list[i].pending = entry.getAddress("pending");
            debt_list[i].value = entry.getUInt("value");
            i++;
        }

        for (j = 0; j < entries1.size(); j++)
        {
            entry = entries1.get(j);
            debt_list[i].creditor = entry.getAddress("creditor");
            debt_list[i].debtor = entry.getAddress("debtor");
            debt_list[i].ddl = entry.getUInt("ddl");
            debt_list[i].pending = entry.getAddress("pending");
            debt_list[i].value = entry.getUInt("value");
            i++;
        }

        if (companies[msg.sender].cType == BANK)
        {
            for (j = 0; j < entries2.size(); j++)
            {
                entry = entries2.get(j);
                debt_list[i].creditor = entry.getAddress("creditor");
                debt_list[i].debtor = entry.getAddress("debtor");
                debt_list[i].ddl = entry.getUInt("ddl");
                debt_list[i].pending = entry.getAddress("pending");
                debt_list[i].value = entry.getUInt("value");
                i++;
            }
        }

        return (SUCC, debt_list);
    }


    /*
    描述 :  债权人发起，（债权人，债务人，还款日期）如有则直接修改value，否则插入一条新记录
    参数 ：
            债务人地址，还款日期，金额

    返回值：
            参数一： 存在相同元组返回0，不存在返回1，修改失败返回-1，添加失败返回-2
            参数二： 当前记录中的欠款数额
    */
    function addTransaction(address debtor, uint256 ddl, uint256 value) public returns (int)
    {
        // 打开表
        Table table = openTable();

        // 查询
        Condition condition;
        condition = table.newCondition();
        condition.EQ("creditor", toString(msg.sender));
        condition.EQ("debtor", toString(debtor));
        condition.EQ("ddl", int(ddl));
        Entries entries = table.select(id, condition);

        Entry entry;
        if (entries.size() == 0)
        {
            entry = table.newEntry();
            entry.set("value", value);
            entry.set("creditor", msg.sender);
            entry.set("debtor", debtor);
            entry.set("ddl", ddl);
            entry.set("pending", address(0));
            if (table.insert(id, entry) != 1)
            {
                return DB_ERR;
            }
        }
        else
        {
            entry = entries.get(0);
            entry.set("value", value + entry.getUInt("value"));
            if (table.update(id, entry, condition) != 1)
            {
                return DB_ERR;
            }
        }
        return SUCC;
    }


    /*
    描述 :  债权人发起，向银行账户申请转移债券，设置pending为银行账户
    参数 ：
            债权人地址，债务人地址，还款日期

    返回值：
            参数一： 成功则返回0，若没有可抵消数据则返回-1，修改失败返回-2
    */
    function mortgage(address debtor, uint256 ddl, address bank, uint256 value) public returns (int)
    {
        if (companies[bank].cType != BANK)
        {
            return NOT_BANK;
        }
        // 打开表
        Table table = openTable();
        // 查询
        Condition condition;
        condition.EQ("creditor", toString(msg.sender));
        condition.EQ("debtor", toString(debtor));
        condition.EQ("ddl", int(ddl));
        Entries entries = table.select(id, condition);
        if (entries.size() == 0)
        {
            return NOT_EXIST;
        }

        Entry entry = entries.get(0);
        uint256 cur_value = entry.getUInt("value");
        if (cur_value < value)
        {
            return OVERFLOW;
        }
        else
        {
            entry.set("pending", bank);
            entry.set("value", value);
            if (table.update(id, entry, condition) != 1)
            {
                return DB_ERR;
            }
            if (cur_value > value)
            {
                entry = table.newEntry();
                entry.set("creditor", msg.sender);
                entry.set("debtor", debtor);
                entry.set("ddl", ddl);
                entry.set("pending", address(0));
                entry.set("value", cur_value - value);
                if (table.insert(id, entry) != 1)
                {
                    return DB_ERR;
                }
            }
        }
        return SUCC;
    }


    /*
    描述 :  银行可以取消pending（设为0）将债权人改为自己
    参数 ：
            债权人地址，债务人地址，还款日期

    返回值：
            参数一： 成功则返回0，若没有可抵消数据则返回-1，修改失败返回-2
    */
    function redemption(address creditor, address debtor, uint256 ddl) public returns(int)
    {
        if (companies[msg.sender].cType != BANK)
        {
            return NOT_BANK;
        }
        // 打开表
        Table table = openTable();
        // 查询
        Condition condition;
        condition.EQ("creditor", toString(creditor));
        condition.EQ("debtor", toString(debtor));
        condition.EQ("ddl", int(ddl));
        condition.EQ("pending", toString(msg.sender));
        Entries entries = table.select(id, condition);
        if (entries.size() == 0)
        {
            return NOT_EXIST;
        }

        Entry entry = entries.get(0);
        uint256 value = entry.getUInt("value");
        entry.set("creditor", msg.sender);
        entry.set("pending", address(0));
        if(table.update(id, entry, condition) != 1)
        {
            return DB_ERR;
        }
        return SUCC;
    }
    
    /*
    描述 :  功能二：债权人发起，减少记录金额，插入一条新记录金额为减少的金额（“插入”同样按照功能一的方式先做判断，看是修改还是插入）
    参数 ：
            转让债权人地址，债务人地址，还款日期，转让金额

    返回值：
            参数一： 转让成功返回0，因指定债权记录不存在转让失败返回-1，因指定债权金额不足转让失败返回-2，数据库操作异常返回-3
    */
    function creditAssignment(address destinationCreditor, address debtor, uint256 ddl, uint256 assignmentValue) public returns (int)
    {
        // 打开表
        Table table = openTable();

        Condition condition = table.newCondition();
        condition.EQ("creditor", toString(msg.sender));
        condition.EQ("debtor", toString(debtor));
        condition.EQ("ddl", int(ddl));

        Entries entries =table.select(id, condition);
        if (entries.size() == 0)  //指定债权不存在
        {
            return NOT_EXIST;
        }
        Entry entry = entries.get(0);
        uint256 originValue = entry.getUInt("value");
        if (originValue < assignmentValue)  //指定债权金额不足
        {
            return OVERFLOW;
        }
        else  //债权金额与转让金额相等
        {
            //更新转让债权人的新债权记录
            entry.set("creditor", destinationCreditor);
            entry.set("pending", address(0));
            entry.set("value", assignmentValue);
            if (table.update(id, entry, condition) != 1)     //数据库操作异常
            {
                return DB_ERR;
            }
            if (originValue > assignmentValue)
            {
                entry = table.newEntry();
                entry.set("creditor", msg.sender);
                entry.set("debtor", debtor);
                entry.set("ddl", ddl);
                entry.set("pending", address(0));
                entry.set("value", originValue - assignmentValue);
                if (table.insert(id, entry) != 1)     //数据库操作异常
                {
                    return DB_ERR;
                }
            }
        }
        return SUCC;
    }

    /*
    描述 :  功能四：债权人发起，（判断时间）删除一条记录
    参数 ：
            债权人地址，债务人地址，还款日期

    返回值：
            参数一： 删除成功返回0，指定债权记录不存在返回-1，数据库操作异常返回-2
    */
    function deleteTransaction(address debtor, uint256 ddl) public returns (int)
    {
        // 打开表
        Table table = openTable();

        Condition condition = table.newCondition();
        condition.EQ("creditor", toString(msg.sender));
        condition.EQ("debtor", toString(debtor));
        condition.EQ("ddl", int(ddl));

        Entries entries =table.select(id, condition);
        if (entries.size() == 0)  //指定债权记录不存在
        {
            return NOT_EXIST;
        }

        if (table.remove(id,condition) != 0)     //数据库操作异常
        {
            return DB_ERR;
        }
        return SUCC;
    }

}