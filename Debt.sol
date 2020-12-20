pragma solidity>=0.4.24 <0.6.11;
pragma experimental ABIEncoderV2;

import "./Table.sol";

contract Debt
{
    struct Company
    {
        string id;
    }
    mapping(address => Company) public companies;

    int OTHER = 0;
    int BANK = 1;

    TableFactory tf;
    constructor() public
    {
        tf = TableFactory(0x1001);
        // 构造函数中创建debt表
        // 应收账款表, key : creditor, field : debtor,ddl,value
        // |所有者(主码)|债权人  |债务人 |还款日期|金额 |
        // |------------|--------|-------|--------|-----|
        // |owner       |creditor|debtor |ddl     |value|
        // |string      |string  |string |int     |int  |
        //
        // 创建表
        tf.createTable("debt", "owner", "creditor,debtor,ddl,value");

        // 构造函数中创建account表
        // 账户表, key : id
        // |用户名(主码)|公司类型|
        // |------------|--------|
        // |id          |type    |
        // |address     |int     |
        //
        // 创建表
        tf.createTable("account", "id", "type");
    }


    /*
    返回码：
    MORTGAGE_TO_DEBTOR：以欠条向银行抵押，其中欠条的债务人就是这个银行，从而引发错误。
    NOT_BANK：当某操作对象必须是银行，但不是银行，引发错误。
    REGISTERED：该地址已注册账户，引发错误。
    ID_EXIST：注册时该用户名已存在，引发错误。
    OVERFLOW：转移欠条时，指定金额超出欠条金额，引发错误。
    NOT_EXIST：该欠条不存在，引发错误。
    DB_ERR：数据库操作出错。
    SUCC：成功。
    */
    int MORTGAGE_TO_DEBTOR = -7;
    int NOT_BANK = -6;
    int REGISTERED = -5;
    int ID_EXIST = -4;
    int OVERFLOW = -3;
    int NOT_EXIST = -2;
    int DB_ERR = -1;
    int SUCC = 0;


    /*
        - 描述：公司账户注册
        - 公有：是
        - 参数：
            - id：公司账户名
            - type：公司类型
        - 返回值：
            - 返回码
    */
    function register(string id, int Type) public returns(int)
    {
        Table table = tf.openTable("account");
        Condition condition = table.newCondition();
        Entries entries;
        entries = table.select(companies[msg.sender].id, condition);
        if (entries.size() != 0)
        {
            return REGISTERED;
        }

        entries = table.select(id, condition);
        if (entries.size() != 0)
        {
            return ID_EXIST;
        }

        Entry entry = table.newEntry();
        entry.set("type", Type);
        if (table.insert(id, entry) != 1)
        {
            return DB_ERR;
        }
        companies[msg.sender].id = id;
        return SUCC;
    }


    struct DEBT
    {
        string owner;
        string creditor;
        string debtor;
        int ddl;
        int value;
    }

    /*
        - 描述：查询所有者为自己的全部debt
        - 公有：是
        - 参数：无
        - 返回值：
            - DEBT数组
    */
    function select() public returns (DEBT [] memory)
    {
        Table table = tf.openTable("debt");
        Condition condition = table.newCondition();
        Entries entries = table.select(companies[msg.sender].id, condition);

        DEBT[] memory debt_list = new DEBT[](uint(entries.size()));
        Entry entry;
        for (uint i = 0; i < uint(entries.size()); i++)
        {
            entry = entries.get(int(i));
            debt_list[i].owner = companies[msg.sender].id;
            debt_list[i].creditor = entry.getString("creditor");
            debt_list[i].debtor = entry.getString("debtor");
            debt_list[i].ddl = entry.getInt("ddl");
            debt_list[i].value = entry.getInt("value");
        }
        return debt_list;
    }


    /*
        - 描述：添加一个欠条，如果存在相关欠条更新其value，否则插入一条新的欠条
        - 公有：否
        - 参数：
            - id：欠条的onwner
            - creditor：欠条的creditor
            - debtor：欠条的debtor
            - ddl：欠条的ddl
            - value：欠条的value
        - 返回值：
            - 返回码
    */
    function insert_core(string id, string creditor, string debtor, int ddl, int value) private returns (int)
    {
        Table table = tf.openTable("debt");
        Condition condition = table.newCondition();
        condition.EQ("creditor", creditor);
        condition.EQ("debtor", debtor);
        condition.EQ("ddl", ddl);
        Entries entries = table.select(id, condition);

        Entry entry;
        if (entries.size() == 0)
        {
            entry = table.newEntry();
            entry.set("creditor", creditor);
            entry.set("debtor", debtor);
            entry.set("ddl", ddl);
            entry.set("value", value);
            if (table.insert(id, entry) != 1)
            {
                return DB_ERR;
            }
        }
        else
        {
            entry = entries.get(0);
            entry.set("value", entry.getInt("value") + value);
            if (table.update(id, entry, condition) != 1)
            {
                return DB_ERR;
            }
        }
        return SUCC;
    }


    /*
        - 描述：添加一个欠条，其中owner和creditor均为自己
        - 公有：是
        - 参数：
            - debtor：欠条的debtor
            - ddl：欠条的ddl
            - value：欠条的value
        - 返回值：
            - 返回码
    */
    function insert(string debtor, int ddl, int value) public returns (int)
    {
        return insert_core(companies[msg.sender].id, companies[msg.sender].id, debtor, ddl, value);
    }


    /*
        - 描述：判断该公司账户是不是银行
        - 公有：否
        - 参数：
            - bank：判断的公司账户名
        - 返回值：
            - 返回码
    */
    function is_bank(string bank) private returns (int)
    {
        Table table;
        Condition condition;
        Entries entries;

        table = tf.openTable("account");
        condition = table.newCondition();
        condition.EQ("type", BANK);
        entries = table.select(bank, condition);
        if (entries.size() != 1)
        {
            return NOT_BANK;
        }
        return SUCC;
    }


    /*
        - 描述：用自己的欠条向银行申请抵押，将owner设为银行，creditor仍设为自己，欠条由正常态转变为挂起态。
        - 公有：是
        - 参数：
            - bank：银行账户名
            - debtor：欠条的debtor
            - ddl：欠条的ddl
            - value：需要抵押的value
        - 返回值：
            - 返回码
    */
    function mortgage(string bank, string debtor, int ddl, int value) public returns (int)
    {
        if (keccak256(abi.encodePacked(bank)) == keccak256(abi.encodePacked(debtor)))
        {
            return MORTGAGE_TO_DEBTOR;
        }
        if (is_bank(bank) == NOT_BANK)
        {
            return NOT_BANK;
        }

        Table table = tf.openTable("debt");
        Condition condition = table.newCondition();
        condition.EQ("creditor", companies[msg.sender].id);
        condition.EQ("debtor", debtor);
        condition.EQ("ddl", ddl);
        Entries entries = table.select(companies[msg.sender].id, condition);
        if (entries.size() == 0)
        {
            return NOT_EXIST;
        }

        Entry entry = entries.get(0);
        int cur_value = entry.getInt("value");
        if (cur_value < value)
        {
            return OVERFLOW;
        }

        if (cur_value == value)
        {
            if (table.remove(companies[msg.sender].id, condition) != 1)
            {
                return DB_ERR;
            }
        }
        else
        {
            entry.set("value", cur_value - value);
            if (table.update(companies[msg.sender].id, entry, condition) != 1)
            {
                return DB_ERR;
            }
        }

        return insert_core(bank, companies[msg.sender].id, debtor, ddl, value);
    }


    /*
        - 描述：银行处理指定抵押申请，若同意将creditor设为银行，若拒绝将owner设为申请者，欠条由挂起态转变为正常态。
        - 公有：是
        - 参数：
            - boolean：0为拒绝，非0为同意
            - creditor：欠条的creaditor
            - debtor：欠条的debtor
            - ddl：欠条的ddl
        - 返回值：
            - 返回码
    */
    function permit(int boolean, string creditor, string debtor, int ddl) public returns(int)
    {
        if (is_bank(companies[msg.sender].id) == NOT_BANK)
        {
            return NOT_BANK;
        }

        Table table = tf.openTable("debt");
        Condition condition = table.newCondition();
        condition.EQ("creditor", creditor);
        condition.EQ("debtor", debtor);
        condition.EQ("ddl", ddl);
        Entries entries = table.select(companies[msg.sender].id, condition);
        if (entries.size() == 0)
        {
            return NOT_EXIST;
        }

        Entry entry = entries.get(0);
        if (boolean == 0)
        {
            if(table.remove(companies[msg.sender].id, condition) != 1)
            {
                return DB_ERR;
            }
            return insert_core(creditor, creditor, debtor, ddl, entry.getInt("value"));
        }
        entry.set("creditor", companies[msg.sender].id);
        if (table.update(companies[msg.sender].id, entry, condition) != 1)
        {
            return DB_ERR;
        }
        return SUCC;
    }


    /*
        - 描述：转移部分或全部正常态的欠条给别人，如果目标是欠条的debtor视为还款，如果目标不是欠条的debtor视为交易欠条
        - 公有：是
        - 参数：
            - creditor：转移目标
            - debtor：欠条的debtor
            - ddl：欠条的ddl
            - value：需要转移的value
        - 返回值：
            - 返回码
    */
    function assign(string creditor, string debtor, int ddl, int value) public returns (int)
    {
        Table table = tf.openTable("debt");
        Condition condition = table.newCondition();
        condition.EQ("creditor", companies[msg.sender].id);
        condition.EQ("debtor", debtor);
        condition.EQ("ddl", ddl);

        Entries entries = table.select(companies[msg.sender].id, condition);
        if (entries.size() == 0)
        {
            return NOT_EXIST;
        }
        Entry entry = entries.get(0);
        int cur_value = entry.getInt("value");
        if (cur_value < value)
        {
            return OVERFLOW;
        }

        if(cur_value == value)
        {
            if(table.remove(companies[msg.sender].id, condition) != 1)
            {
                return DB_ERR;
            }
        }
        else
        {
            entry.set("value", cur_value - value);
            if (table.update(companies[msg.sender].id, entry, condition) != 1)
            {
                return DB_ERR;
            }
        }

        if (keccak256(abi.encodePacked(creditor)) == keccak256(abi.encodePacked(debtor)))
        {
            return SUCC;
        }
        return insert_core(creditor, creditor, debtor, ddl, value);
    }
}
