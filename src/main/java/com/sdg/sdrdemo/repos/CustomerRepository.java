package com.sdg.sdrdemo.repos;

import java.util.List;

import org.springframework.data.repository.PagingAndSortingRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.sdg.sdrdemo.models.Customer;

@Repository
public interface CustomerRepository extends PagingAndSortingRepository<Customer, Long> {
	 public List<Customer> findByNameLike(@Param("name") String name);
}
