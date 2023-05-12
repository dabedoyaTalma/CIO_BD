/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalConveyor2]    Script Date: 12/05/2023 15:06:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ======================================================================================================================================
-- Description: Function for Businees Rules "Conveyor" 
--
-- Change History:
--  2019-10-29	Diomer Bedoya: Funtion created
--  2020-03-11	Amilkar Martínez: Validamos que no se cobre el segundo conveyor en caso de que tenga carga o descarga para VIVA COLOMBIA
--	2021-08-31	Sebastián Jaramillo: Se incluye RN de VivaAerobus
--	2022-02-04	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-06-15	Sebastián Jaramillo: Se ajusta RN VivaAerobus para tener en cuenta cuando se cobre el tema de carga o descarga
--	2022-07-28	Sebastián Jaramillo: Se ajusta RN VivaColombia para indicar explícitamente servicios internacionales
--	2022-09-28	Sebastián Jaramillo: Se adicionan RN Arajet
-- ======================================================================================================================================

--SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalConveyor2](12251,4,1,1,20,12,'2019-08-30')
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalConveyor2](
	@ServiceHeaderId BIGINT,
	@AirportId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@AirplaneTypeId INT,
	@DestinationId INT,
	@DateService DATE
)
RETURNS @Result TABLE(ROW INT IDENTITY, StartDate DATETIME, EndDate DATETIME, Time INT, AdditionalService BIT, AdditionalStartHour DATETIME, AdditionalEndHour DATETIME, AdditionalTime INT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150), Fraction VARCHAR(25), TimeLeftover INT)
AS
BEGIN
	DECLARE @TimeLeftover FLOAT=0
	DECLARE	@ExtraText VARCHAR(50) = ''

	DECLARE @ServiceDetail AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO
	INSERT	@ServiceDetail
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'CONVEYOR',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) Time_total, 
			DS.cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 132 AND --SEGUNDO CONVEYOR
			DS.EncabezadoServicioId = @ServiceHeaderId
	
	IF (SELECT SUM(TiempoTotal) FROM @ServiceDetail) = 0 RETURN --SE TIENE ESTA LINEA PARA OPTIMIZAR EL RENDIMIENTO

	--AEROLINEAS ARGENTINAS / AEROLINEAS ARGENTINAS
	IF (@CompanyId=67 AND @BillingToCompany=67)
	BEGIN
		IF (@DateService >= '2022-11-15')
		BEGIN
			RETURN --Tiene incluido el segundo conveyor en el contrato.
		END
	END

	--ARAJET / ARAJET
	IF (@CompanyId=272 AND @BillingToCompany=272)
	BEGIN
		IF (@DateService >= '2022-09-15')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --NO TIENEN TARIFA PERO SE SACA ADICIONAL EN CASO QUE LO MARQUEN PARA QUE NO DIGAN QUE EL SISTEMA NO LO ESTA SACANDO SI LO MARCAN....

			RETURN
		END
	END

	--ULTRA AIR / ULTRA AIR
	IF (@CompanyId=259 AND @BillingToCompany=259)
	BEGIN
		IF (@DateService >= '2022-01-20')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --NO TIENEN TARIFA PERO SE SACA ADICIONAL EN CASO QUE LO MARQUEN PARA QUE NO DIGAN QUE EL SISTEMA NO LO ESTA SACANDO SI LO MARCAN....

			RETURN
		END
	END
	
	IF (@CompanyId = 60 AND @BillingToCompany = 90) --VIVA COLOMBIA                           
	BEGIN
		IF (CIOServicios.UFN_CIO_InternationalFlight(@AirportId, @DestinationId) = 1)
		BEGIN
			SET @ExtraText = ' INTERNACIONAL'
		END

		--Validamos que no se cobre el segundo conveyor en caso de que tenga carga o descarga para VIVA COLOMBIA
		IF NOT EXISTS((SELECT TOP(1) TipoActividadId FROM CIOServicios.DetalleServicio 
					   WHERE EncabezadoServicioId = @ServiceHeaderId AND TipoActividadId IN (302/*Carga*/,303/*Descarga*/) AND Activo = 1))
		BEGIN
			IF (@DateService >= '2017-02-01')
			BEGIN
				INSERT	@Result 
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,	CONCAT(AdditionalServiceName, @ExtraText) AdditionalServiceName
					,	FractionName
					,	TimeLeftover
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
				RETURN
			END

			RETURN
		END
	END
	
	IF (@CompanyId = 205 AND @BillingToCompany = 205) --ARUBA AIRLINES                       
	BEGIN
		IF (@DateService >= '2019-08-23')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			RETURN
		END

		RETURN
	END

	IF (@CompanyId = 70 AND @BillingToCompany = 70) --INTERJET                         
	BEGIN
		IF (@AirportId IN (17) AND @DateService >= '2019-11-22') --CTG
		BEGIN
			RETURN 
		END

		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
		RETURN
	END

	IF (@CompanyId = 51 AND @BillingToCompany = 51 AND @DateService >= '2020-02-01') --LANCO
	BEGIN	
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
		RETURN
	END

	IF (@CompanyId = 81 AND @BillingToCompany = 81) --JET SMART                        
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
		RETURN

		RETURN
	END

	IF (@CompanyId = 192 AND @BillingToCompany = 192) --VIVA PERU                           
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
		RETURN

		RETURN
	END

	IF (@CompanyId = 111 AND @BillingToCompany = 56) --WINGO                          
	BEGIN
		IF (@DateService <= '2019-06-30')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			RETURN
		END
		ELSE
		BEGIN
			--TIENE INCLUIDO EL SEGUNDO CONVEYOR DESDE EL 2019-07-01 EN LA TARIFA
			RETURN
		END

		RETURN
	END

	IF (@CompanyId = 255 AND @BillingToCompany = 255) --VIVAAEROBUS                          
	BEGIN
		IF (@DateService >= '2022-06-01')
		BEGIN
			--Validamos que no se cobre el segundo conveyor en caso de que tenga carga o descarga para VIVA COLOMBIA
			IF NOT EXISTS((SELECT TOP(1) TipoActividadId FROM CIOServicios.DetalleServicio WHERE EncabezadoServicioId = @ServiceHeaderId AND TipoActividadId IN (302/*Carga*/,303/*Descarga*/) AND Activo = 1))
			BEGIN
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
				RETURN
			END

			RETURN
		END

		IF (@DateService BETWEEN '2021-08-21' AND '2022-05-31')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			RETURN
		END

		RETURN
	END

	IF (	@CompanyId = 39 
		AND @BillingToCompany = 1 
		AND @AirportId = 3 
		AND @DestinationId = 7
		AND @AirplaneTypeId = 60) -- RNG INSEL AIR DESTINO ARUBA
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0,NULL,NULL)
		RETURN
	END
		
	RETURN
END