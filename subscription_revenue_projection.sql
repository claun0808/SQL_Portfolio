/*
  This code was used in Snowflake to project the monthly counts and revenue of auto-renewing subscriptions for the next 6 months.
  These estimates helped clients forecast their marketing budgets.
  Customers had a variety of different term lengths for their subscription that determined their renewal date(s) (e.g. annual, monthly, quarterly). 
  Each item had its own cadence of selecting customers eligble to renew (e.g. monthly, bi-weekly), here referred to as item_sequence's.
  Example: A customer with a monthly subscription to a bi-weekly item would essentially be renewed every other time that item renewed customers.
*/

--Start out with a base of all active, auto-renewing subscriptions (excluding free subs)
with active_sub as (
    select
        subscription_id,
        item_code,
        term_length,
        auto_renewal_price,
        subscription_final_item_sequence    --this is the last item sequence the subscription is scheduled to receive which will trigger its auto renewal
    from all_subscriptions
    where
        is_term_active = true and
        is_auto_renewal = true and
        auto_renewal_price > 0
),

--Create an array of all the item issue sequences that will be fulfilled in the next 6 months.
item_sequence as (
    select 
        item_code,
        date_trunc(month, item_renewal_date)       as item_renewal_date_trunc,
        array_agg(item_sequence)                   as item_sequence_array
    from item_issue_setup
    where date_trunc(month, item_renewal_date) <= dateadd(month, 6, current_date())
    group by 1, 2
),

--Create a table with the month start dates of the next 6 months.
report_date as (
    select
        date_trunc(month, current_date())                        as report_date,
        0                                                        as month_number
    union all
    select
        date_trunc(month, dateadd(month, 1, current_date()))     as report_date,
        1                                                        as month_number
    union all
    select
        date_trunc(month, dateadd(month, 2, current_date()))     as report_date,
        2                                                        as month_number
    union all
    select
        date_trunc(month, dateadd(month, 3, current_date()))     as report_date,
        3                                                        as month_number
    union all
    select
        date_trunc(month, dateadd(month, 4, current_date()))     as report_date,
        4                                                        as month_number
    union all
    select
        date_trunc(month, dateadd(month, 5, current_date()))     as report_date,
        5                                                        as month_number
    union all
    select
        date_trunc(month, dateadd(month, 6, current_date()))     as report_date,
        6                                                        as month_number
),

--Create an array of the next 7 item sequences (to include current month) that will be fulfilled for each subscription

sub_sequence as (
    select
        subscription_id,
        item_code,
        term_length,
        auto_renewal_price,
        array_construct(subscription_final_item_sequence,
                        subscription_final_item_sequence + term_length,
                        subscription_final_item_sequence + term_length * 2,
                        subscription_final_item_sequence + term_length * 3,
                        subscription_final_item_sequence + term_length * 4,
                        subscription_final_item_sequence + term_length * 5,
                        subscription_final_item_sequence + term_length * 6,
                        subscription_final_item_sequence + term_length * 7
                        )   as sub_sequence_array
    from active_sub
),

--Flag any month where a subscription_id's issue sequences overlap with the issues to be sent that month
month_flag as (

    select
        sub.subscription_id,
        sub.item_code,
        sub.term_length,
        sub.auto_renewal_price,

        iff(chg.month_number = 0 and
                arrays_overlap(item_sequence_array, sub_sequence_array),
                1,
                0
            ) as month_0_count,
        iff(chg.month_number = 1 and
                arrays_overlap(item_sequence_array, sub_sequence_array),
                1,
                0
            ) as month_1_count,
        iff(chg.month_number = 2 and
                arrays_overlap(item_sequence_array, sub_sequence_array),
                1,
                0
            ) as month_2_count,
        iff(chg.month_number = 3 and
                arrays_overlap(item_sequence_array, sub_sequence_array),
                1,
                0
            ) as month_3_count,
        iff(chg.month_number = 4 and
                arrays_overlap(item_sequence_array, sub_sequence_array),
                1,
                0
            ) as month_4_count,
        iff(chg.month_number = 5 and
                arrays_overlap(item_sequence_array, sub_sequence_array),
                1,
                0
            ) as month_5_count,
        iff(chg.month_number = 6 and
                arrays_overlap(item_sequence_array, sub_sequence_array),
                1,
                0
            ) as month_6_count,
        iff(chg.month_number = 0,
            chg.report_date,
            null
        )                                       as month_0,
        iff(chg.month_number = 1,
            chg.report_date,
            null
        )                                       as month_1,
        iff(chg.month_number = 2,
            chg.report_date,
            null
        )                                       as month_2,
        iff(chg.month_number = 3,
            chg.report_date,
            null
        )                                       as month_3,
        iff(chg.month_number = 4,
            chg.report_date,
            null
        )                                       as month_4,
        iff(chg.month_number = 5,
            chg.report_date,
            null
        )                                       as month_5,
        iff(chg.month_number = 6,
            chg.report_date,
            null
        )                                       as month_6
    from sub_sequence as sub

    inner join item_sequence as itm on
        sub.item_code = itm.item_code
    
    inner join report_date as chg on
        itm.item_renewal_date_trunc = chg.report_date

),

final as (
    select
        item_code,

        sum(month_0_count)                      as month_0_count,
        sum(iff(month_0_count = 1,
            auto_renewal_price,
            0)
        )                                       as month_0_revenue,
        sum(month_1_count)                      as month_1_count,
        sum(iff(month_1_count = 1,
            auto_renewal_price,
            0)
        )                                       as month_1_revenue,
        sum(month_2_count)                      as month_2_count,        
        sum(iff(month_2_count = 1,
            auto_renewal_price,
            0)
        )                                       as month_2_revenue,
        
        sum(month_3_count)                      as month_3_count,
        sum(iff(month_3_count = 1,
            auto_renewal_price,
            0)
        )                                       as month_3_revenue,        
        sum(month_4_count)                      as month_4_count,
        sum(iff(month_4_count = 1,
            auto_renewal_price,
            0)
        )                                       as month_4_revenue,
        sum(month_5_count)                      as month_5_count,
        sum(iff(month_5_count = 1,
            auto_renewal_price,
            0)
        )                                       as month_5_revenue,
        sum(month_6_count)                      as month_6_count,
        sum(iff(month_6_count = 1,
            auto_renewal_price,
            0)
        )                                       as month_6_revenue

    from month_flag

    where 
          month_0_count +
          month_1_count +
          month_2_count +
          month_3_count +
          month_4_count +
          month_5_count +
          month_6_count > 0

    group by 1
    
)

select * from final
