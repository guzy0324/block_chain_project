pragma solidity>=0.4.24 <0.6.11;
pragma experimental ABIEncoderV2;

import "./Table.sol";

contract Debt
{
    int OTHER = 0;
    int BANK = 1;
    struct Company
    {
        string id;
    }

    mapping(address => Company) public companies;

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

    int MORTGAGE_FROM_Debtor = -7
    int DB_ERR = -6;
    int OVERFLOW = -5;
    int BANK_NOT_EXIST = -4;
    int NOT_EXIST = -3;
    int ID_EXIST = -2;
    int REGISTERED = -1;
    int SUCC = 0;
    
    /*
    描述 : 公司注册
    参数 ：
            cType: 公司类型
    返回值：
            无
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
    描述 : 查询相关debt
    参数 ：
            无

    返回值：
            参数一： 成功返回0, 账户不存在返回-1
            参数二： 第一个参数为0时有效，debt_list
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
    描述 :  债权人发起，（债权人，债务人，还款日期）如有则直接修改value，否则插入一条新记录
    参数 ：
            债务人地址，还款日期，金额

    返回值：
            参数一： 存在相同元组返回0，不存在返回1，修改失败返回-1，添加失败返回-2
            参数二： 当前记录中的欠款数额
    */
    function addTransaction(string debtor, int ddl, int value) public returns (int)
    {
        Table table = tf.openTable("debt");
        Condition condition = table.newCondition();
        condition.EQ("creditor", companies[msg.sender].id);
        condition.EQ("debtor", debtor);
        condition.EQ("ddl", ddl);
        Entries entries = table.select(companies[msg.sender].id, condition);

        Entry entry;
        if (entries.size() == 0)
        {
            entry = table.newEntry();
            entry.set("creditor", companies[msg.sender].id);
            entry.set("debtor", debtor);
            entry.set("ddl", ddl);
            entry.set("value", value);
            if (table.insert(companies[msg.sender].id, entry) != 1)
            {
                return DB_ERR;
            }
        }
        else
        {
            entry = entries.get(0);
            entry.set("value", entry.getInt("value") + value);
            if (table.update(companies[msg.sender].id, entry, condition) != 1)
            {
                return DB_ERR;
            }
        }
        return SUCC;
    }


    /*
    描述 :  债权人发起，向银行账户申请转移债券
    参数 ：
            债权人地址，债务人地址，还款日期

    返回值：
            参数一： 成功则返回0，若没有可抵消数据则返回-1，修改失败返回-2
    */
    function mortgage(string bank, string debtor, int ddl, int value) public returns (int)
    {
        if(bank == debtor){
            return MORTGAGE_FROM_Debtor;
        }
        Table table;
        Condition condition;
        Entries entries;

        table = tf.openTable("account");
        condition = table.newCondition();
        condition.EQ("type", BANK);
        entries = table.select(companies[msg.sender].id, condition);
        if (entries.size() != 1)
        {
            return BANK_NOT_EXIST;
        }

        table = tf.openTable("debt");
        condition.EQ("creditor", companies[msg.sender].id);
        condition.EQ("debtor", debtor);
        condition.EQ("ddl", ddl);
        entries = table.select(companies[msg.sender].id, condition);
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
        else
        {
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
            entry.set("value", value);
            if (addTransaction(bank, debtor, ddl) != 0)
            {
                return DB_ERR;
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
    function redemption(string creditor, string debtor, int ddl) public returns(int)
    {
        Table table;
        Condition condition;
        Entries entries;

        table = tf.openTable("account");
        condition = table.newCondition();
        condition.EQ("type", BANK);
        entries = table.select(companies[msg.sender].id, condition);
        if (entries.size() != 1)
        {
            return BANK_NOT_EXIST;
        }

        table = tf.openTable("debt");
        condition.EQ("creditor", creditor);
        condition.EQ("debtor", debtor);
        condition.EQ("ddl", ddl);
        entries = table.select(companies[msg.sender].id, condition);
        if (entries.size() == 0)
        {
            return NOT_EXIST;
        }

        Entry entry = entries.get(0);
        entry.set("creditor", companies[msg.sender].id);
        if (table.update(companies[msg.sender].id, entry, condition) != 1)
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
    function creditAssignment(string creditor, string debtor, int ddl, int value) public returns (int)
    {
        if(creditor != debtor){
            Table table = tf.openTable("debt");
            Condition condition = table.newCondition();
            condition.EQ("creditor", companies[msg.sender].id);
            condition.EQ("debtor", debtor);
            condition.EQ("ddl", ddl);

            Entries entries = table.select(companies[msg.sender].id, condition);
            if (entries.size() == 0)  //指定债权不存在
            {
                return NOT_EXIST;
            }
            Entry entry = entries.get(0);
            int cur_value = entry.getInt("value");
            if (cur_value < value)  //指定债权金额不足
            {
                return OVERFLOW;
            }
            else  
            {
                //债权金额与转让金额相等
                if(cur_value == value)
                {
                    if(table.remove(companies[msg.sender].id, condition) != 1)
                    {
                        return DB_ERR;
                    }
                }
                else
                {
                    entry = table.newEntry();
                    entry.set("creditor", companies[msg.sender].id);
                    entry.set("debtor", debtor);
                    entry.set("ddl", ddl);
                    entry.set("value", cur_value - value);
                    if (table.insert(companies[msg.sender].id, entry) != 1)     //数据库操作异常
                    {
                        return DB_ERR;
                    }
                }
                //更新转让债权人的新债权记录
                entry.set("creditor", creditor);
                entry.set("value", value);
                if (addTransaction(creditor, debtor, ddl) != 0)     //数据库操作异常
                {
                    return DB_ERR;
                }
                
            }
            return SUCC;
        }
        else
        {
            Table table = tf.openTable("debt");
            Condition condition = table.newCondition();
            condition.EQ("creditor", companies[msg.sender].id);
            condition.EQ("debtor", debtor);
            condition.EQ("ddl", ddl);
            Entries entries = table.select(companies[msg.sender].id, condition);
            if (entries.size() == 0)  //指定债权不存在
            {
                return NOT_EXIST;
            }
            Entry entry = entries.get(0);
            int cur_value = entry.getInt("value");
            if (cur_value > value)
            {
                entry = table.newEntry();
                entry.set("creditor", companies[msg.sender].id);
                entry.set("debtor", debtor);
                entry.set("ddl", ddl);
                entry.set("value", cur_value - value);
                if (table.insert(companies[msg.sender].id, entry) != 1)     //数据库操作异常
                {
                    return DB_ERR;
                }
            }
            else
            {
                if(cur_value == value)
                {
                    if(table.remove(companies[msg.sender].id, condition) != 1)
                    {
                        return DB_ERR;
                    }
                }
                else
                {
                    entry = table.newEntry();
                    entry.set("creditor", companies[msg.sender].id);
                    entry.set("debtor", debtor);
                    entry.set("ddl", ddl);
                    entry.set("value", value - cur_value);
                    if (table.insert(companies[msg.sender].id, entry) != 1)     //数据库操作异常
                    {
                        return DB_ERR;
                    }
                    if(table.remove(companies[msg.sender].id, condition) != 1)
                    {
                        return DB_ERR;
                    }
                }
            }
        }
    }

    /*
    描述 :  功能四：债权人发起，（判断时间）删除一条记录
    参数 ：
            债权人地址，债务人地址，还款日期

    返回值：
            参数一： 删除成功返回0，指定债权记录不存在返回-1，数据库操作异常返回-2
    */
    function deleteTransaction(string debtor, int ddl) public returns (int)
    {
        Table table = tf.openTable("debt");
        Condition condition = table.newCondition();
        condition.EQ("creditor", companies[msg.sender].id);
        condition.EQ("debtor", debtor);
        condition.EQ("ddl", ddl);

        if (table.remove(companies[msg.sender].id, condition) != 1)     //数据库操作异常
        {
            return DB_ERR;
        }
        return SUCC;
    }
}